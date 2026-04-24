#!/usr/bin/env swift

import AppKit
import Foundation
import PDFKit

enum WrapFailure: LocalizedError {
    case usage
    case fileMissing(String)
    case notJSON
    case noUsableJSONInGPTResponse(String)
    case unsupportedShape
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .usage:
            return "Usage: swift scripts/wrap-chat-history-batch.swift /path/to/input.json [/path/to/output.json]"
        case .fileMissing(let path):
            return "Could not find file at \(path)"
        case .notJSON:
            return "The input file is not valid JSON."
        case .noUsableJSONInGPTResponse(let fileName):
            return "No usable BubblePath JSON was found in \(fileName). If this is a GPT response, try the GPT fenced or embedded example files, or check `CHAT_HISTORY_SHAPE_GUIDE.md`."
        case .unsupportedShape:
            return "The input JSON must be a full chat-history batch, a root object with a \"chats\" array, a root chats array, or a single chat entry object. If this came from GPT, compare it against the GPT fenced/embedded example files or check `CHAT_HISTORY_SHAPE_GUIDE.md`."
        case .writeFailed(let path):
            return "Could not write normalized batch to \(path)"
        }
    }
}

private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
}()

private let decoder = JSONDecoder()

private func textutilExtractText(from url: URL) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
    process.arguments = ["-convert", "txt", "-stdout", url.path]

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = Pipe()

    do {
        try process.run()
    } catch {
        return nil
    }

    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }
    return String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func strippedHTMLText(from data: Data) -> String? {
    guard let html = String(data: data, encoding: .utf8) else { return nil }
    let withoutScripts = html.replacingOccurrences(
        of: "<script\\b[^>]*>[\\s\\S]*?</script>",
        with: " ",
        options: [.regularExpression, .caseInsensitive]
    )
    let withoutStyles = withoutScripts.replacingOccurrences(
        of: "<style\\b[^>]*>[\\s\\S]*?</style>",
        with: " ",
        options: [.regularExpression, .caseInsensitive]
    )
    let withoutTags = withoutStyles.replacingOccurrences(
        of: "<[^>]+>",
        with: " ",
        options: [.regularExpression]
    )
    let decoded = withoutTags
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#34;", with: "\"")
        .replacingOccurrences(of: "&apos;", with: "'")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&nbsp;", with: " ")
    return decoded.replacingOccurrences(
        of: "\\s+",
        with: " ",
        options: .regularExpression
    )
    .trimmingCharacters(in: .whitespacesAndNewlines)
}

private enum JSONExtractionKind: String {
    case direct = "direct JSON"
    case fenced = "fenced GPT-style JSON"
    case embedded = "embedded GPT-style JSON"
}

private func extractFencedJSON(from text: String) -> String? {
    let lines = text.components(separatedBy: .newlines)
    let candidates = extractFencedJSONCandidates(from: lines)
    for candidate in candidates {
        if let data = candidate.data(using: .utf8),
           looksLikeSupportedImportPayload(in: data) {
            return candidate
        }
    }
    return candidates.first
}

private func preferredImportJSON(from text: String) -> (json: String, kind: JSONExtractionKind, skippedEarlierJSONNoise: Bool)? {
    let fencedCandidates = extractFencedJSONCandidates(from: text.components(separatedBy: .newlines))
    let embeddedCandidates = extractEmbeddedJSONCandidates(from: text)

    for (index, candidate) in fencedCandidates.enumerated() {
        if let data = candidate.data(using: .utf8),
           looksLikeSupportedImportPayload(in: data) {
            return (candidate, .fenced, index > 0 || !embeddedCandidates.isEmpty)
        }
    }

    for (index, candidate) in embeddedCandidates.enumerated() {
        if let data = candidate.data(using: .utf8),
           looksLikeSupportedImportPayload(in: data) {
            return (candidate, .embedded, index > 0 || !fencedCandidates.isEmpty)
        }
    }

    if let candidate = fencedCandidates.first {
        return (candidate, .fenced, false)
    }

    if let candidate = embeddedCandidates.first {
        return (candidate, .embedded, false)
    }

    return nil
}

private func extractFencedJSONCandidates(from lines: [String]) -> [String] {
    guard !lines.isEmpty else { return [] }
    var insideFence = false
    var collected: [String] = []
    var candidates: [String] = []

    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if !insideFence {
            guard trimmedLine.hasPrefix("```") else { continue }

            let fenceLanguage = String(trimmedLine.dropFirst(3))
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if fenceLanguage.isEmpty || fenceLanguage == "json" {
                insideFence = true
                collected.removeAll(keepingCapacity: true)
            }
            continue
        }

        if trimmedLine == "```" {
            let json = collected
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !json.isEmpty {
                candidates.append(json)
            }
            insideFence = false
            collected.removeAll(keepingCapacity: true)
            continue
        }

        collected.append(line)
    }

    return candidates
}

private func extractEmbeddedJSONCandidates(from text: String) -> [String] {
    let characters = Array(text)
    var candidates: [String] = []

    for startIndex in characters.indices {
        let opening = characters[startIndex]
        guard opening == "{" || opening == "[" else { continue }

        let closing: Character = opening == "{" ? "}" : "]"
        var depth = 0
        var inString = false
        var isEscaped = false

        for endIndex in startIndex..<characters.count {
            let character = characters[endIndex]

            if inString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
                continue
            }

            if character == "\"" {
                inString = true
                continue
            }

            if character == opening {
                depth += 1
            } else if character == closing {
                depth -= 1
                if depth == 0 {
                    let candidate = String(characters[startIndex...endIndex])
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if let data = candidate.data(using: .utf8),
                       (try? JSONSerialization.jsonObject(with: data)) != nil {
                        candidates.append(candidate)
                    }

                    break
                }
            }
        }
    }

    return candidates
}

private func extractEmbeddedJSON(from text: String) -> String? {
    let candidates = extractEmbeddedJSONCandidates(from: text)
    guard !candidates.isEmpty else { return nil }

    for candidate in candidates {
        if let data = candidate.data(using: .utf8),
           looksLikeSupportedImportPayload(in: data) {
            return candidate
        }
    }

    return candidates.first
}

private func looksLikeGPTResponseFile(_ url: URL, text: String) -> Bool {
    let ext = url.pathExtension.lowercased()
    guard ["txt", "text", "md", "markdown", "rtf", "doc", "docx", "odt", "html", "htm", "pdf", "webarchive"].contains(ext) else { return false }

    let lowercased = text.lowercased()
    return lowercased.contains("bubblepath")
        || lowercased.contains("chat-history-batch")
        || lowercased.contains("\"bubbletitle\"")
        || lowercased.contains("\"excerpt\"")
        || lowercased.contains("```json")
}

private func readableText(from url: URL) throws -> String {
    let ext = url.pathExtension.lowercased()

    if ext == "rtf" || ext == "doc" || ext == "docx" || ext == "odt" {
        if let text = textutilExtractText(from: url), !text.isEmpty {
            return text
        }
        if ext == "rtf" {
            return try NSAttributedString(
                url: url,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
            .string
            .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    if ext == "html" || ext == "htm" {
        let data = try Data(contentsOf: url)
        if let text = textutilExtractText(from: url), !text.isEmpty {
            return text
        }
        if let stripped = strippedHTMLText(from: data), !stripped.isEmpty {
            return stripped
        }
        return try NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
        )
        .string
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    if ext == "pdf" {
        guard let document = PDFDocument(url: url) else { return "" }
        return (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    if ext == "webarchive" {
        let data = try Data(contentsOf: url)
        if let webArchive = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
           let mainResource = webArchive["WebMainResource"] as? [String: Any],
           let resourceData = mainResource["WebResourceData"] as? Data {
            if let stripped = strippedHTMLText(from: resourceData), !stripped.isEmpty {
                return stripped
            }
            if let html = try? NSAttributedString(
                data: resourceData,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil
            ).string.trimmingCharacters(in: .whitespacesAndNewlines),
               !html.isEmpty {
                return html
            }
        }
        return ""
    }

    return try String(contentsOf: url, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func flexibleJSONObject(from data: Data, url: URL) throws -> (object: Any, extractionKind: JSONExtractionKind, skippedEarlierJSONNoise: Bool) {
    if let json = try? JSONSerialization.jsonObject(with: data) {
        return (json, .direct, false)
    }

    let text: String
    if ["rtf", "html", "htm", "pdf", "webarchive"].contains(url.pathExtension.lowercased()) {
        text = try readableText(from: url)
    } else if let decodedText = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
        !decodedText.isEmpty {
        text = decodedText
    } else if let extractedText = try? readableText(from: url),
              !extractedText.isEmpty {
        text = extractedText
    } else {
        throw WrapFailure.notJSON
    }

    if let preferredJSON = preferredImportJSON(from: text),
       let preferredData = preferredJSON.json.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: preferredData) {
        return (json, preferredJSON.kind, preferredJSON.skippedEarlierJSONNoise)
    }

    if looksLikeGPTResponseFile(url, text: text) {
        throw WrapFailure.noUsableJSONInGPTResponse(url.lastPathComponent)
    }

    throw WrapFailure.notJSON
}

private struct BatchEnvelope: Codable {
    var app: String
    var kind: String
    var version: Int
    var sourceApp: String?
    var sourceChatTitle: String?
    var sourceChatID: String?
    var sourceURL: String?
    var chats: [ChatEntry]
}

private struct ChatEntry: Codable {
    var bubbleTitle: String
    var excerpt: String
    var tags: [String]?
    var bubbleType: String?
    var sourceChatTitle: String?
    var sourceChatID: String?
    var sourceURL: String?
    var capturedAt: String?
}

private func trim(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func cleaned(_ entry: ChatEntry) -> ChatEntry {
    ChatEntry(
        bubbleTitle: trim(entry.bubbleTitle) ?? entry.bubbleTitle,
        excerpt: trim(entry.excerpt) ?? entry.excerpt,
        tags: entry.tags?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
        bubbleType: trim(entry.bubbleType),
        sourceChatTitle: trim(entry.sourceChatTitle),
        sourceChatID: trim(entry.sourceChatID),
        sourceURL: trim(entry.sourceURL),
        capturedAt: trim(entry.capturedAt)
    )
}

private struct NormalizedBatchResult {
    var shapeLabel: String
    var batch: BatchEnvelope
}

private func normalizedBatch(from object: Any) -> NormalizedBatchResult? {
    if let envelope = try? decode(BatchEnvelope.self, from: object),
       envelope.kind == "chat-history-batch" {
        return NormalizedBatchResult(
            shapeLabel: "full BubblePath batch",
            batch: BatchEnvelope(
                app: trim(envelope.app) ?? "BubblePath",
                kind: "chat-history-batch",
                version: 1,
                sourceApp: trim(envelope.sourceApp),
                sourceChatTitle: trim(envelope.sourceChatTitle),
                sourceChatID: trim(envelope.sourceChatID),
                sourceURL: trim(envelope.sourceURL),
                chats: envelope.chats.map(cleaned)
            )
        )
    }

    if let root = object as? [String: Any],
       let chatsValue = root["chats"],
       let chats = try? decode([ChatEntry].self, from: chatsValue) {
        return NormalizedBatchResult(
            shapeLabel: "root object with chats",
            batch: BatchEnvelope(
                app: "BubblePath",
                kind: "chat-history-batch",
                version: 1,
                sourceApp: trim(root["sourceApp"] as? String),
                sourceChatTitle: trim(root["sourceChatTitle"] as? String),
                sourceChatID: trim(root["sourceChatID"] as? String),
                sourceURL: trim(root["sourceURL"] as? String),
                chats: chats.map(cleaned)
            )
        )
    }

    if let chats = try? decode([ChatEntry].self, from: object) {
        return NormalizedBatchResult(
            shapeLabel: "root array",
            batch: BatchEnvelope(
                app: "BubblePath",
                kind: "chat-history-batch",
                version: 1,
                sourceApp: nil,
                sourceChatTitle: nil,
                sourceChatID: nil,
                sourceURL: nil,
                chats: chats.map(cleaned)
            )
        )
    }

    if let chat = try? decode(ChatEntry.self, from: object) {
        return NormalizedBatchResult(
            shapeLabel: "single entry",
            batch: BatchEnvelope(
                app: "BubblePath",
                kind: "chat-history-batch",
                version: 1,
                sourceApp: nil,
                sourceChatTitle: nil,
                sourceChatID: nil,
                sourceURL: nil,
                chats: [cleaned(chat)]
            )
        )
    }

    return nil
}

private func decode<T: Decodable>(_ type: T.Type, from object: Any) throws -> T {
    let data = try JSONSerialization.data(withJSONObject: object, options: [])
    return try decoder.decode(T.self, from: data)
}

private func looksLikeChatEntryObject(_ object: [String: Any]) -> Bool {
    if let bubbleTitle = object["bubbleTitle"] as? String,
       !bubbleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return true
    }
    if let excerpt = object["excerpt"] as? String,
       !excerpt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return true
    }
    return false
}

private func looksLikeSupportedImportPayload(in data: Data) -> Bool {
    if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let app = object["app"] as? String,
           app.trimmingCharacters(in: .whitespacesAndNewlines) == "BubblePath" {
            return true
        }
        if let kind = object["kind"] as? String {
            let trimmedKind = kind.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedKind == "chat-history-batch" || trimmedKind == "capture-batch" {
                return true
            }
        }
        if let captures = object["captures"] as? [Any], !captures.isEmpty { return true }
        if let chats = object["chats"] as? [[String: Any]], !chats.isEmpty { return true }
        if looksLikeChatEntryObject(object) { return true }
    }

    if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
       !array.isEmpty,
       array.allSatisfy(looksLikeChatEntryObject) {
        return true
    }

    return false
}

do {
    guard CommandLine.arguments.count >= 2 else {
        throw WrapFailure.usage
    }

    let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
    guard FileManager.default.fileExists(atPath: inputURL.path) else {
        throw WrapFailure.fileMissing(inputURL.path)
    }

    let outputURL: URL = {
        if CommandLine.arguments.count >= 3 {
            return URL(fileURLWithPath: CommandLine.arguments[2])
        }

        let baseName = inputURL.deletingPathExtension().lastPathComponent
        return inputURL.deletingLastPathComponent()
            .appendingPathComponent("\(baseName)-wrapped.json")
    }()

    let data = try Data(contentsOf: inputURL)
    let extraction = try flexibleJSONObject(from: data, url: inputURL)
    let json = extraction.object

    guard let normalized = normalizedBatch(from: json) else {
        throw WrapFailure.unsupportedShape
    }

    let encoded = try encoder.encode(normalized.batch)
    do {
        try encoded.write(to: outputURL, options: .atomic)
    } catch {
        throw WrapFailure.writeFailed(outputURL.path)
    }

    FileHandle.standardOutput.write(Data("Detected \(normalized.shapeLabel) input with \(normalized.batch.chats.count) entr\(normalized.batch.chats.count == 1 ? "y" : "ies").\n".utf8))
    if extraction.extractionKind != .direct {
        FileHandle.standardOutput.write(Data("Extracted \(extraction.extractionKind.rawValue) before wrapping.\n".utf8))
        if extraction.skippedEarlierJSONNoise {
            FileHandle.standardOutput.write(Data("Skipped earlier unrelated JSON before choosing the BubblePath payload.\n".utf8))
        }
    }
    FileHandle.standardOutput.write(Data("Wrote normalized BubblePath chat-history batch to \(outputURL.path)\n".utf8))
} catch {
    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    FileHandle.standardError.write(Data("Wrap failed: \(message)\n".utf8))
    exit(EXIT_FAILURE)
}
