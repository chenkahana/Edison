import Combine
import Foundation
import OSLog

/// Runs on-device analysis over clipboard history (language model on text; Vision and, on macOS 27,
/// the language model on images), one item at a time, off the main thread.
///
/// New items go first; the rest of history is backfilled newest-first with a pause between
/// items, so it never competes with what you're doing. Nothing runs while Intelligence is off or
/// Low Power Mode is on. Results are written back as `ClipboardIntelligence` metadata only.
@MainActor
final class IntelligenceCoordinator: ObservableObject {
    /// Bump one of these to re-run that stage over items processed by an older pass.
    static let textModelPass = 1
    static let visionPass = 1
    static let imageModelPass = 1
    static let searchVectorPass = 1
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
    private let imageModel: @Sendable (URL) async throws -> OnDeviceImageModel.Result?
    private let availabilityProvider: () -> OnDeviceTextModel.Availability
    private let imageModelAvailabilityProvider: () -> Bool
    private let vectorStore: IntelligenceVectorStore
    private let searchIndex: SemanticSearchIndex
    private var imageModelAvailable = false
    /// Items whose analysis couldn't complete this launch, so the backlog doesn't spin on them.
    private var failedIDs: Set<UUID> = []
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
        imageModel: @escaping @Sendable (URL) async throws -> OnDeviceImageModel.Result? = { try await OnDeviceImageModel.describe(imageURL: $0) },
        availabilityProvider: @escaping () -> OnDeviceTextModel.Availability = { OnDeviceTextModel.availability },
        imageModelAvailabilityProvider: @escaping () -> Bool = { OnDeviceImageModel.isAvailable },
        vectorStore: IntelligenceVectorStore = .shared,
        searchIndex: SemanticSearchIndex = .shared,
        isLowPowerMode: @escaping () -> Bool = { ProcessInfo.processInfo.isLowPowerModeEnabled },
        backlogPause: Duration = .seconds(1)
    ) {
        self.textModel = textModel
        self.imageModel = imageModel
        self.availabilityProvider = availabilityProvider
        self.imageModelAvailabilityProvider = imageModelAvailabilityProvider
        self.vectorStore = vectorStore
        self.searchIndex = searchIndex
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
        refreshAvailability()
        let items = historyItems()
        let vectorStore = self.vectorStore
        let searchIndex = self.searchIndex
        Task { [weak self] in
            // Classifying a whole history takes tens of milliseconds; do it off the main thread so
            // the kind cache makes the progress count (and the Hub's first render) cheap. Stored
            // search vectors load in the same pass.
            await Task.detached(priority: .utility) {
                for item in items { _ = item.contentKind }
                searchIndex.load(itemIDs: items.map(\.id), from: vectorStore)
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
        refreshAvailability()
        refreshProgress()
        kick()
    }

    private func refreshAvailability() {
        textModelAvailability = availabilityProvider()
        imageModelAvailable = imageModelAvailabilityProvider()
        Log.intelligence.info("Text model: \(String(describing: self.textModelAvailability), privacy: .public); image model: \(self.imageModelAvailable ? "available" : "unavailable", privacy: .public)")
    }

    func refreshProgress() {
        let eligible = historyItems().filter(isEligible)
        eligibleCount = eligible.count
        processedCount = eligible.filter { !needsWork($0) }.count
    }

    // MARK: - Work selection

    private var canRun: Bool { isEnabled() && !isLowPowerMode() }

    private enum Stage {
        /// The language model on an item's text: kind and topics.
        case textModel
        /// Vision on an image: recognised text, labels, barcodes, feature print.
        case vision
        /// The language model on an image (macOS 27+): caption and topics.
        case imageModel
        /// The language model on an image's recognised text, for topics, where it can't read images.
        case recognizedTextModel
        /// The search vector, built last from everything the other stages found.
        case searchVector
    }

    /// Every stage that applies to the item on this Mac, done or not.
    private func stages(for item: ClipboardItem) -> [Stage] {
        analysisStages(for: item) + [.searchVector]
    }

    private func analysisStages(for item: ClipboardItem) -> [Stage] {
        switch item.payload {
        case let .text(text):
            guard textModelAvailability == .available,
                  [.text, .code, .terminal].contains(item.contentKind),
                  text.trimmingCharacters(in: .whitespacesAndNewlines).count >= Self.minimumTextLength else { return [] }
            return [.textModel]
        case .image:
            if imageModelAvailable { return [.vision, .imageModel] }
            // Until Vision has run, whether there's enough recognised text to tag isn't known.
            let recognized = item.intelligence?.recognizedText ?? ""
            let hasText = item.intelligence?.visionPass == nil || recognized.count >= Self.minimumTextLength
            return textModelAvailability == .available && hasText ? [.vision, .recognizedTextModel] : [.vision]
        case .fileURL:
            return []
        }
    }

    /// Other stages reset the pass when they add words, so the vector is rebuilt from them.
    private func searchVectorIsDone(_ item: ClipboardItem) -> Bool {
        (item.intelligence?.searchVectorPass ?? 0) >= Self.searchVectorPass
    }

    private func isDone(_ stage: Stage, _ item: ClipboardItem) -> Bool {
        let intelligence = item.intelligence
        switch stage {
        case .textModel, .recognizedTextModel: return (intelligence?.textModelPass ?? 0) >= Self.textModelPass
        case .vision: return (intelligence?.visionPass ?? 0) >= Self.visionPass
        case .imageModel: return (intelligence?.imageModelPass ?? 0) >= Self.imageModelPass
        case .searchVector: return searchVectorIsDone(item)
        }
    }

    private func isEligible(_ item: ClipboardItem) -> Bool {
        !stages(for: item).isEmpty
    }

    private func needsWork(_ item: ClipboardItem) -> Bool {
        !failedIDs.contains(item.id) && stages(for: item).contains { !isDone($0, item) }
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
            let ranModel = await analyze(item)
            // An item a stage couldn't finish (unreadable image file) isn't picked again this launch.
            if let current = historyItems().first(where: { $0.id == item.id }), needsWork(current) {
                failedIDs.insert(item.id)
            }
            refreshProgress()
            // The pause spaces out model and Vision work; building a search vector alone is cheap.
            if isBacklog && isBacklogThrottled && ranModel {
                try? await Task.sleep(for: backlogPause)
            }
        }
    }

    /// Runs the item's pending stages in order, one model call at a time, each off the main actor.
    /// Returns whether any stage other than the search vector ran.
    private func analyze(_ item: ClipboardItem) async -> Bool {
        var ranModel = false
        for stage in stages(for: item) {
            guard !Task.isCancelled,
                  let current = historyItems().first(where: { $0.id == item.id }),
                  stages(for: current).contains(where: { $0 == stage }),
                  !isDone(stage, current) else { continue }
            let started = ContinuousClock.now
            ranModel = ranModel || stage != .searchVector
            switch stage {
            case .textModel:
                guard case let .text(text) = current.payload else { continue }
                await runTextModel(on: text, itemID: current.id, keepKind: true)
            case .recognizedTextModel:
                guard let text = current.intelligence?.recognizedText else { continue }
                await runTextModel(on: text, itemID: current.id, keepKind: false)
            case .vision:
                await runVision(on: current)
            case .imageModel:
                await runImageModel(on: current)
            case .searchVector:
                await buildSearchVector(for: current)
            }
            let elapsed = ContinuousClock.now - started
            Log.intelligence.debug("\(String(describing: stage), privacy: .public): \(elapsed.formatted(.units(allowed: [.milliseconds])), privacy: .public)")
        }
        return ranModel
    }

    private func runTextModel(on text: String, itemID: UUID, keepKind: Bool) async {
        let textModel = self.textModel
        // Detached so the model call and its prompt building never run on the main actor.
        let outcome = await Task.detached(priority: .utility) { () -> Result<OnDeviceTextModel.Result?, Error> in
            do {
                return .success(try await textModel(text))
            } catch {
                return .failure(error)
            }
        }.value
        guard case let .success(result) = outcome else { return }
        applyUpdate(itemID) { intelligence in
            if keepKind { intelligence.modelKind = result?.kind }
            intelligence.topics = result.map { ClipboardIntelligence.normalizedTopics($0.topics) }
            intelligence.textModelPass = Self.textModelPass
            intelligence.searchVectorPass = nil
        }
    }

    private func runVision(on item: ClipboardItem) async {
        guard case let .image(image) = item.payload else { return }
        let imageURL = ImageStore.imagesDirectoryURL.appendingPathComponent(image.imagePath)
        let vectorStore = self.vectorStore
        // Earlier images' feature prints, to find one this image nearly duplicates.
        let candidates: [UUID] = historyItems().compactMap { other in
            guard other.id != item.id, case .image = other.payload,
                  other.createdAt <= item.createdAt, other.intelligence?.visionPass != nil else { return nil }
            return other.id
        }
        let analysis = await Task.detached(priority: .utility) { () -> (OnDeviceImageAnalyzer.Result, UUID?)? in
            guard let result = OnDeviceImageAnalyzer.analyze(imageURL: imageURL) else { return nil }
            var nearest: (UUID, Float)?
            if let print = result.featurePrint {
                for id in candidates {
                    guard let other = vectorStore.load(kind: .featurePrint, itemID: id),
                          let distance = OnDeviceImageAnalyzer.distance(between: print, and: other),
                          distance < OnDeviceImageAnalyzer.nearDuplicateDistance,
                          distance < (nearest?.1 ?? .infinity) else { continue }
                    nearest = (id, distance)
                }
            }
            return (result, nearest?.0)
        }.value
        guard let (result, nearDuplicateOf) = analysis else { return }
        if let print = result.featurePrint {
            vectorStore.save(print, kind: .featurePrint, itemID: item.id)
        }
        applyUpdate(item.id) { intelligence in
            intelligence.recognizedText = result.recognizedText
            intelligence.imageLabels = result.labels
            intelligence.barcodePayload = result.barcodePayload
            intelligence.nearDuplicateOf = nearDuplicateOf
            intelligence.visionPass = Self.visionPass
            intelligence.searchVectorPass = nil
        }
    }

    private func runImageModel(on item: ClipboardItem) async {
        guard case let .image(image) = item.payload else { return }
        let imageURL = ImageStore.imagesDirectoryURL.appendingPathComponent(image.imagePath)
        let imageModel = self.imageModel
        let outcome = await Task.detached(priority: .utility) { () -> Result<OnDeviceImageModel.Result?, Error> in
            do {
                return .success(try await imageModel(imageURL))
            } catch {
                return .failure(error)
            }
        }.value
        guard case let .success(result) = outcome else { return }
        applyUpdate(item.id) { intelligence in
            intelligence.caption = result?.caption
            intelligence.topics = result.map { ClipboardIntelligence.normalizedTopics($0.topics) }
            intelligence.imageModelPass = Self.imageModelPass
            intelligence.searchVectorPass = nil
        }
    }

    private func buildSearchVector(for item: ClipboardItem) async {
        let document = SemanticSearchIndex.document(for: item)
        let vector = await Task.detached(priority: .utility) {
            document.flatMap(SemanticSearchIndex.vector(for:))
        }.value
        if let vector {
            vectorStore.save(SemanticSearchIndex.encode(vector), kind: .searchVector, itemID: item.id)
        }
        searchIndex.set(vector, for: item.id)
        applyUpdate(item.id) { intelligence in
            intelligence.searchVectorPass = Self.searchVectorPass
        }
    }
}
