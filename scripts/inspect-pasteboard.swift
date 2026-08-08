#!/usr/bin/env swift

import AppKit
import CryptoKit
import Foundation

private let cliUsage = """
Usage:
  swift scripts/inspect-pasteboard.swift --label <label> --source <source> [--output <path>]

Options:
  --label <label>    Stable fixture label, for example textedit-bold-link.
  --source <source>  Source application name, for example TextEdit.
  --output <path>    Atomically write JSON to this path. Defaults to stdout.
  --help             Show this help.

The inspector records pasteboard metadata, byte counts, and SHA-256 hashes.
It emits no raw clipboard bytes. Hashes are stable fingerprints and are sensitive.
Inspect only deliberate synthetic, non-sensitive samples.
"""

private struct Arguments {
    let label: String
    let source: String
    let outputPath: String?

    static func parse(_ values: [String]) throws -> Arguments {
        var label: String?
        var source: String?
        var outputPath: String?
        var index = 0

        func value(after option: String) throws -> String {
            let valueIndex = index + 1
            guard valueIndex < values.count, !values[valueIndex].hasPrefix("--") else {
                throw InspectorError.usage("Missing value for \(option).")
            }
            index = valueIndex
            return values[valueIndex]
        }

        while index < values.count {
            switch values[index] {
            case "--help", "-h":
                throw InspectorError.help
            case "--label":
                guard label == nil else {
                    throw InspectorError.usage("--label may be supplied only once.")
                }
                label = try value(after: "--label")
            case "--source":
                guard source == nil else {
                    throw InspectorError.usage("--source may be supplied only once.")
                }
                source = try value(after: "--source")
            case "--output":
                guard outputPath == nil else {
                    throw InspectorError.usage("--output may be supplied only once.")
                }
                outputPath = try value(after: "--output")
            default:
                throw InspectorError.usage("Unknown option: \(values[index])")
            }
            index += 1
        }

        guard let label, !label.isEmpty else {
            throw InspectorError.usage("--label is required and may not be empty.")
        }
        guard let source, !source.isEmpty else {
            throw InspectorError.usage("--source is required and may not be empty.")
        }
        if let outputPath, outputPath.isEmpty {
            throw InspectorError.usage("--output may not be empty.")
        }

        return Arguments(label: label, source: source, outputPath: outputPath)
    }
}

private enum InspectorError: Error, CustomStringConvertible {
    case help
    case usage(String)
    case unreadableRepresentation(itemIndex: Int, typeIndex: Int, type: String)
    case pasteboardChanged(start: Int, end: Int)
    case emptyPasteboard
    case noReadableRepresentations

    var description: String {
        switch self {
        case .help:
            return cliUsage
        case .usage(let message):
            return "\(message)\n\n\(cliUsage)"
        case .unreadableRepresentation(let itemIndex, let typeIndex, let type):
            return "Could not read item \(itemIndex), type \(typeIndex) (\(type)); no raw bytes were logged."
        case .pasteboardChanged(let start, let end):
            return "Pasteboard changed during inspection (changeCount \(start) -> \(end)); copy again and retry."
        case .emptyPasteboard:
            return "Pasteboard has no items; copy a deliberate synthetic sample and retry."
        case .noReadableRepresentations:
            return "Pasteboard items have no readable declared representations; copy again and retry."
        }
    }
}

private struct Inspection: Codable {
    let schemaVersion: Int
    let label: String
    let source: String
    let changeCount: Int
    let items: [Item]
}

private struct Item: Codable {
    let index: Int
    let types: [Representation]
}

private struct Representation: Codable {
    let index: Int
    let type: String
    let byteCount: Int
    let sha256: String
}

private func hash(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func inspect(arguments: Arguments) throws -> Inspection {
    let pasteboard = NSPasteboard.general
    let initialChangeCount = pasteboard.changeCount
    let pasteboardItems = pasteboard.pasteboardItems ?? []

    let items = try pasteboardItems.enumerated().map { itemIndex, pasteboardItem in
        let representations = try pasteboardItem.types.enumerated().map { typeIndex, type in
            guard let data = pasteboardItem.data(forType: type) else {
                throw InspectorError.unreadableRepresentation(
                    itemIndex: itemIndex,
                    typeIndex: typeIndex,
                    type: type.rawValue
                )
            }
            return Representation(
                index: typeIndex,
                type: type.rawValue,
                byteCount: data.count,
                sha256: hash(data)
            )
        }
        return Item(index: itemIndex, types: representations)
    }

    let finalChangeCount = pasteboard.changeCount
    guard initialChangeCount == finalChangeCount else {
        throw InspectorError.pasteboardChanged(start: initialChangeCount, end: finalChangeCount)
    }
    guard !pasteboardItems.isEmpty else {
        throw InspectorError.emptyPasteboard
    }
    guard items.contains(where: { !$0.types.isEmpty }) else {
        throw InspectorError.noReadableRepresentations
    }

    return Inspection(
        schemaVersion: 1,
        label: arguments.label,
        source: arguments.source,
        changeCount: initialChangeCount,
        items: items
    )
}

private func encoded(_ inspection: Inspection) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(inspection)
    data.append(0x0A)
    return data
}

private func write(_ data: Data, outputPath: String?) throws {
    guard let outputPath else {
        FileHandle.standardOutput.write(data)
        return
    }

    let url = URL(fileURLWithPath: outputPath)
    try data.write(to: url, options: .atomic)
}

do {
    let arguments = try Arguments.parse(Array(CommandLine.arguments.dropFirst()))
    try write(encoded(try inspect(arguments: arguments)), outputPath: arguments.outputPath)
} catch InspectorError.help {
    print(cliUsage)
    exit(EXIT_SUCCESS)
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}
