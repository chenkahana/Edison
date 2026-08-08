import CryptoKit
import Foundation
import OSLog

final class ClipboardRepresentationStore {
    static let shared = ClipboardRepresentationStore()

    static let provisionalMaximumRepresentationBytes = 8 * 1024 * 1024
    static let provisionalMaximumItemBytes = 16 * 1024 * 1024
    static let provisionalMaximumStoreBytes = 256 * 1024 * 1024

    private let directoryURL: URL
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "edison.clipboard-representations.store", qos: .utility)

    init(
        directoryURL: URL = HistoryStore.storageDirectory.appendingPathComponent("representations", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.directoryURL = directoryURL.standardizedFileURL
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
    }

    func save(
        representations: [(typeIdentifier: String, data: Data)],
        declaredTypeIdentifiers: [String],
        itemID: UUID
    ) -> ClipboardTextRepresentations {
        queue.sync {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            var stored: [ClipboardRepresentationDescriptor] = []
            var degradations: [ClipboardRepresentationDegradation] = []
            var itemBytes = 0
            var storeBytes = currentStoreBytes()

            for (index, representation) in representations.enumerated() {
                let byteCount = representation.data.count
                let sha256 = Self.sha256(representation.data)
                let reason: ClipboardRepresentationDegradationReason?
                if byteCount > Self.provisionalMaximumRepresentationBytes {
                    reason = .representationSizeLimit
                } else if itemBytes + byteCount > Self.provisionalMaximumItemBytes {
                    reason = .itemSizeLimit
                } else if storeBytes + byteCount > Self.provisionalMaximumStoreBytes {
                    reason = .storeSizeLimit
                } else {
                    reason = nil
                }

                if let reason {
                    degradations.append(.init(
                        typeIdentifier: representation.typeIdentifier,
                        reason: reason,
                        sha256: sha256
                    ))
                    continue
                }

                let relativePath = "\(itemID.uuidString)-\(index).bin"
                guard let url = validatedURL(for: relativePath) else {
                    degradations.append(.init(
                        typeIdentifier: representation.typeIdentifier,
                        reason: .persistenceFailure,
                        sha256: sha256
                    ))
                    continue
                }

                do {
                    try representation.data.write(to: url, options: .atomic)
                    let descriptor = ClipboardRepresentationDescriptor(
                        typeIdentifier: representation.typeIdentifier,
                        relativePath: relativePath,
                        byteCount: byteCount,
                        sha256: sha256
                    )
                    stored.append(descriptor)
                    itemBytes += byteCount
                    storeBytes += byteCount
                } catch {
                    Log.store.error(
                        "ClipboardRepresentationStore: save failed for type \(representation.typeIdentifier, privacy: .public)"
                    )
                    degradations.append(.init(
                        typeIdentifier: representation.typeIdentifier,
                        reason: .persistenceFailure,
                        sha256: sha256
                    ))
                }
            }

            return ClipboardTextRepresentations(
                declaredTypeIdentifiers: declaredTypeIdentifiers,
                storedRepresentations: stored,
                degradations: degradations
            )
        }
    }

    func load(_ descriptor: ClipboardRepresentationDescriptor) throws -> Data {
        try queue.sync {
            guard descriptor.byteCount >= 0,
                  descriptor.byteCount <= Self.provisionalMaximumRepresentationBytes,
                  let url = validatedURL(for: descriptor.relativePath) else {
                throw StoreError.invalidDescriptor
            }

            let resolvedDirectory = directoryURL.resolvingSymlinksInPath().standardizedFileURL
            let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL
            guard resolvedURL.deletingLastPathComponent() == resolvedDirectory else {
                throw StoreError.invalidDescriptor
            }

            let data = try Data(contentsOf: resolvedURL, options: .mappedIfSafe)
            guard data.count == descriptor.byteCount else {
                throw StoreError.byteCountMismatch
            }
            guard Self.sha256(data) == descriptor.sha256 else {
                throw StoreError.hashMismatch
            }
            return data
        }
    }

    func delete(_ representations: ClipboardTextRepresentations?) {
        guard let representations else { return }
        queue.async { [self] in
            for descriptor in representations.storedRepresentations {
                guard let url = self.validatedURL(for: descriptor.relativePath) else { continue }
                try? self.fileManager.removeItem(at: url)
            }
        }
    }

    func reconcile(items: [ClipboardItem]) {
        queue.sync { [self] in
            let livePaths = Set(items.flatMap { item in
                item.textRepresentations?.storedRepresentations.map(\.relativePath) ?? []
            })
            guard let files = try? self.fileManager.contentsOfDirectory(
                at: self.directoryURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { return }

            for file in files where !livePaths.contains(file.lastPathComponent) {
                guard self.validatedURL(for: file.lastPathComponent) == file.standardizedFileURL else { continue }
                try? self.fileManager.removeItem(at: file)
            }
        }
    }

    private func currentStoreBytes() -> Int {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        return files.reduce(into: 0) { total, url in
            let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            total += size ?? 0
        }
    }

    private func validatedURL(for relativePath: String) -> URL? {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              (relativePath as NSString).lastPathComponent == relativePath else { return nil }

        let url = directoryURL.appendingPathComponent(relativePath, isDirectory: false).standardizedFileURL
        guard url.deletingLastPathComponent() == directoryURL else { return nil }
        return url
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    enum StoreError: Error {
        case invalidDescriptor
        case byteCountMismatch
        case hashMismatch
    }
}
