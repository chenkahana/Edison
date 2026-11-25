import Combine
import Foundation
import OSLog

/// Runs on-device analysis over clipboard history, one item at a time, off the main thread.
///
/// New items go first; the rest of history is backfilled newest-first with a pause between
/// items, so it never competes with what you're doing. Nothing runs while Intelligence is off or
/// Low Power Mode is on. Results are written back as `ClipboardIntelligence` metadata only.
@MainActor
final class IntelligenceCoordinator: ObservableObject {
    /// Bump to re-run the text model over items processed by an older pass.
    static let textModelPass = 1
    /// Text shorter than this has too little to label or tag.
    static let minimumTextLength = 12

    @Published private(set) var processedCount = 0
    @Published private(set) var eligibleCount = 0
    @Published private(set) var isWorking = false
    @Published private(set) var textModelAvailability: OnDeviceTextModel.Availability = .unavailable

    var isEnabled: () -> Bool = { true }
    var historyItems: () -> [ClipboardItem] = { [] }
    var applyUpdate: (_ itemID: UUID, _ update: (inout ClipboardIntelligence) -> Void) -> Void = { _, _ in }

    private let textModel: @Sendable (String) async throws -> OnDeviceTextModel.Result?
    private let availabilityProvider: () -> OnDeviceTextModel.Availability
    private let isLowPowerMode: () -> Bool
    private let backlogPause: Duration
    private var priorityIDs: [UUID] = []
    private var isBacklogThrottled = true
    private var worker: Task<Void, Never>?
    private var workerGeneration = 0
    private var powerObserver: NSObjectProtocol?
    /// Nothing runs until history has loaded and `start()` is called (never in unit tests that
    /// skip runtime services).
    private var isStarted = false

    init(
        textModel: @escaping @Sendable (String) async throws -> OnDeviceTextModel.Result? = { try await OnDeviceTextModel.analyze($0) },
        availabilityProvider: @escaping () -> OnDeviceTextModel.Availability = { OnDeviceTextModel.availability },
        isLowPowerMode: @escaping () -> Bool = { ProcessInfo.processInfo.isLowPowerModeEnabled },
        backlogPause: Duration = .seconds(1)
    ) {
        self.textModel = textModel
        self.availabilityProvider = availabilityProvider
        self.isLowPowerMode = isLowPowerMode
        self.backlogPause = backlogPause
    }

    /// Starts (or resumes) processing. Called once history has loaded, and when settings change.
    func start() {
        isStarted = true
        if powerObserver == nil {
            powerObserver = NotificationCenter.default.addObserver(
                forName: .NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.kick()
                }
            }
        }
        textModelAvailability = availabilityProvider()
        Log.intelligence.info("Text model availability: \(String(describing: self.textModelAvailability), privacy: .public)")
        let items = historyItems()
        Task { [weak self] in
            // Classifying a whole history takes tens of milliseconds; do it off the main thread so
            // the kind cache makes the progress count (and the Hub's first render) cheap.
            await Task.detached(priority: .utility) {
                for item in items { _ = item.contentKind }
            }.value
            self?.refreshProgress()
            self?.kick()
        }
    }

    func stop() {
        worker?.cancel()
        worker = nil
        workerGeneration += 1
        isWorking = false
    }

    /// A freshly captured item jumps the backlog. O(1) on the main thread.
    func itemAdded(_ item: ClipboardItem) {
        let state = Log.performance.beginInterval("Intelligence Enqueue")
        defer { Log.performance.endInterval("Intelligence Enqueue", state) }
        guard needsWork(item) else { return }
        priorityIDs.append(item.id)
        kick()
    }

    /// Settings › Process Existing History: works through the backlog without pausing between items.
    func processExistingHistory() {
        isBacklogThrottled = false
        textModelAvailability = availabilityProvider()
        refreshProgress()
        kick()
    }

    func refreshProgress() {
        let eligible = historyItems().filter(isEligible)
        eligibleCount = eligible.count
        processedCount = eligible.filter { !needsWork($0) }.count
    }

    // MARK: - Work selection

    private var canRun: Bool { isEnabled() && !isLowPowerMode() }

    private func isEligible(_ item: ClipboardItem) -> Bool {
        guard textModelAvailability == .available,
              case let .text(text) = item.payload,
              [.text, .code, .terminal].contains(item.contentKind) else { return false }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).count >= Self.minimumTextLength
    }

    private func needsWork(_ item: ClipboardItem) -> Bool {
        isEligible(item) && (item.intelligence?.textModelPass ?? 0) < Self.textModelPass
    }

    /// The next item to analyse and whether it came from the backlog.
    private func nextItem() -> (ClipboardItem, isBacklog: Bool)? {
        let items = historyItems()
        while let id = priorityIDs.first {
            priorityIDs.removeFirst()
            if let item = items.first(where: { $0.id == id }), needsWork(item) {
                return (item, false)
            }
        }
        return items.first(where: needsWork).map { ($0, true) }
    }

    // MARK: - Worker

    private func kick() {
        guard isStarted, worker == nil, canRun else { return }
        workerGeneration += 1
        let generation = workerGeneration
        worker = Task { [weak self] in
            await self?.drain(generation: generation)
        }
    }

    private func drain(generation: Int) async {
        isWorking = true
        defer {
            // A stop() and a new kick() may have replaced this worker while it finished its item.
            if workerGeneration == generation {
                isWorking = false
                worker = nil
                isBacklogThrottled = true
            }
            refreshProgress()
        }
        while !Task.isCancelled, canRun, let (item, isBacklog) = nextItem() {
            await analyze(item)
            refreshProgress()
            if isBacklog && isBacklogThrottled {
                try? await Task.sleep(for: backlogPause)
            }
        }
    }

    private func analyze(_ item: ClipboardItem) async {
        guard case let .text(text) = item.payload else { return }
        let textModel = self.textModel
        let started = ContinuousClock.now
        // Detached so the model call and its prompt building never run on the main actor.
        let outcome = await Task.detached(priority: .utility) { () -> Result<OnDeviceTextModel.Result?, Error> in
            do {
                return .success(try await textModel(text))
            } catch {
                return .failure(error)
            }
        }.value
        guard case let .success(result) = outcome else { return }
        let elapsed = ContinuousClock.now - started
        Log.intelligence.debug("Text model: \(elapsed.formatted(.units(allowed: [.milliseconds])), privacy: .public)")
        applyUpdate(item.id) { intelligence in
            intelligence.modelKind = result?.kind
            intelligence.topics = result.map { ClipboardIntelligence.normalizedTopics($0.topics) }
            intelligence.textModelPass = Self.textModelPass
        }
    }
}
