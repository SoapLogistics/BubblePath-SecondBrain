#!/usr/bin/env swift

import AppKit
import Foundation
import PDFKit

enum ValidationFailure: LocalizedError {
    case usage
    case fileMissing(String)
    case notJSONRoot
    case noUsableJSONInGPTResponse(String)
    case looseShapeDetected(String)
    case wrongApp(String?)
    case wrongKind(String?)
    case wrongVersion(Int?)
    case missingChats
    case emptyChats
    case invalidTopLevelField(field: String, expectation: String)
    case invalidTopLevelSourceURL(String)
    case invalidChat(index: Int, field: String)
    case invalidBubbleType(index: Int, value: String)
    case invalidTags(index: Int)
    case invalidSourceURL(index: Int, value: String)
    case invalidCapturedAt(index: Int, value: String)

    var errorDescription: String? {
        switch self {
        case .usage:
            return "Usage: swift scripts/validate-chat-history-batch.swift /path/to/chat-history.json [/path/to/another-chat-history.json ...]"
        case .fileMissing(let path):
            return "Could not find file at \(path)"
        case .notJSONRoot:
            return "The file is not a JSON object."
        case .noUsableJSONInGPTResponse(let fileName):
            return "No usable BubblePath JSON was found in \(fileName). If this is a GPT response, try the GPT fenced or embedded example files, or check `CHAT_HISTORY_SHAPE_GUIDE.md`."
        case .looseShapeDetected(let shape):
            return "This looks like \(shape) chat-history JSON, not a full BubblePath batch. You can import it directly into BubblePathMac, or wrap it first with `swift scripts/wrap-chat-history-batch.swift your-file.json` or `Wrap Chat History.command`."
        case .wrongApp(let app):
            if let app {
                return "Expected app \"BubblePath\" but found \"\(app)\"."
            }
            return "Expected an \"app\" field with value \"BubblePath\"."
        case .wrongKind(let kind):
            if let kind {
                return "Expected kind \"chat-history-batch\" but found \"\(kind)\"."
            }
            return "Expected a \"kind\" field with value \"chat-history-batch\"."
        case .wrongVersion(let version):
            if let version {
                return "Expected version 1 but found \(version)."
            }
            return "Expected a numeric \"version\" field with value 1."
        case .missingChats:
            return "Missing \"chats\" array. If this came from GPT, compare it against the GPT fenced/embedded example files or check `CHAT_HISTORY_SHAPE_GUIDE.md`."
        case .emptyChats:
            return "The \"chats\" array is empty. If this came from GPT, compare it against the GPT fenced/embedded example files or check `CHAT_HISTORY_SHAPE_GUIDE.md`."
        case .invalidTopLevelField(let field, let expectation):
            return "Top-level \"\(field)\" must be \(expectation)."
        case .invalidTopLevelSourceURL(let value):
            return "Top-level sourceURL \"\(value)\" is invalid."
        case .invalidChat(let index, let field):
            return "Chat entry \(index + 1) is missing a usable \(field)."
        case .invalidBubbleType(let index, let value):
            return "Chat entry \(index + 1) has invalid bubbleType \"\(value)\"."
        case .invalidTags(let index):
            return "Chat entry \(index + 1) has invalid tags. Tags must be an array of non-empty strings."
        case .invalidSourceURL(let index, let value):
            return "Chat entry \(index + 1) has invalid sourceURL \"\(value)\"."
        case .invalidCapturedAt(let index, let value):
            return "Chat entry \(index + 1) has invalid capturedAt \"\(value)\"."
        }
    }
}

let allowedBubbleTypes: Set<String> = ["thought", "question", "decision", "seed", "file", "chat"]
let iso8601Formatter = ISO8601DateFormatter()

func textutilExtractText(from url: URL) -> String? {
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

func strippedHTMLText(from data: Data) -> String? {
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

enum JSONExtractionKind: String {
    case direct = "direct JSON"
    case fenced = "fenced GPT-style JSON"
    case embedded = "embedded GPT-style JSON"
}

func extractFencedJSON(from text: String) -> String? {
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

func preferredImportJSON(from text: String) -> (json: String, kind: JSONExtractionKind, skippedEarlierJSONNoise: Bool)? {
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

func extractFencedJSONCandidates(from lines: [String]) -> [String] {
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

func extractEmbeddedJSONCandidates(from text: String) -> [String] {
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

func extractEmbeddedJSON(from text: String) -> String? {
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

func looksLikeGPTResponseFile(_ url: URL, text: String) -> Bool {
    let ext = url.pathExtension.lowercased()
    guard ["txt", "text", "md", "markdown", "rtf", "doc", "docx", "odt", "html", "htm", "pdf", "webarchive"].contains(ext) else { return false }

    let lowercased = text.lowercased()
    return lowercased.contains("bubblepath")
        || lowercased.contains("chat-history-batch")
        || lowercased.contains("\"bubbletitle\"")
        || lowercased.contains("\"excerpt\"")
        || lowercased.contains("```json")
}

func readableText(from url: URL) throws -> String {
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

func flexibleJSONObject(from data: Data, url: URL) throws -> (object: Any, extractionKind: JSONExtractionKind, skippedEarlierJSONNoise: Bool) {
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
        throw ValidationFailure.notJSONRoot
    }

    if let preferredJSON = preferredImportJSON(from: text),
       let preferredData = preferredJSON.json.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: preferredData) {
        return (json, preferredJSON.kind, preferredJSON.skippedEarlierJSONNoise)
    }

    if looksLikeGPTResponseFile(url, text: text) {
        throw ValidationFailure.noUsableJSONInGPTResponse(url.lastPathComponent)
    }

    throw ValidationFailure.notJSONRoot
}

func trimmedString(_ value: Any?) -> String? {
    guard let value = value as? String else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

func validateChatEntry(_ entry: [String: Any], index: Int) throws {
    guard trimmedString(entry["bubbleTitle"]) != nil else {
        throw ValidationFailure.invalidChat(index: index, field: "\"bubbleTitle\"")
    }

    guard trimmedString(entry["excerpt"]) != nil else {
        throw ValidationFailure.invalidChat(index: index, field: "\"excerpt\"")
    }

    if let bubbleType = trimmedString(entry["bubbleType"]), !allowedBubbleTypes.contains(bubbleType) {
        throw ValidationFailure.invalidBubbleType(index: index, value: bubbleType)
    }

    if let tags = entry["tags"] {
        guard let tagValues = tags as? [Any], tagValues.allSatisfy({
            guard let tag = $0 as? String else { return false }
            return !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            throw ValidationFailure.invalidTags(index: index)
        }

        if tagValues.isEmpty == false, tagValues.count == 0 {
            throw ValidationFailure.invalidTags(index: index)
        }
    }

    if let sourceURL = trimmedString(entry["sourceURL"]),
       URL(string: sourceURL) == nil {
        throw ValidationFailure.invalidSourceURL(index: index, value: sourceURL)
    }

    if let capturedAt = trimmedString(entry["capturedAt"]),
       iso8601Formatter.date(from: capturedAt) == nil {
        throw ValidationFailure.invalidCapturedAt(index: index, value: capturedAt)
    }
}

func looksLikeChatEntry(_ object: [String: Any]) -> Bool {
    trimmedString(object["bubbleTitle"]) != nil || trimmedString(object["excerpt"]) != nil
}

func looksLikeSupportedImportPayload(in data: Data) -> Bool {
    if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let app = trimmedString(object["app"]), app == "BubblePath" { return true }
        if let kind = trimmedString(object["kind"]),
           kind == "chat-history-batch" || kind == "capture-batch" {
            return true
        }
        if let captures = object["captures"] as? [Any], !captures.isEmpty { return true }
        if let chats = object["chats"] as? [[String: Any]], !chats.isEmpty { return true }
        if looksLikeChatEntry(object) { return true }
    }

    if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
       !array.isEmpty,
       array.allSatisfy(looksLikeChatEntry) {
        return true
    }

    return false
}

func validate(url: URL) throws -> String {
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw ValidationFailure.fileMissing(url.path)
    }

    let data = try Data(contentsOf: url)
    let extraction = try flexibleJSONObject(from: data, url: url)
    let json = extraction.object

    if let arrayRoot = json as? [[String: Any]] {
        if arrayRoot.allSatisfy(looksLikeChatEntry) {
            throw ValidationFailure.looseShapeDetected("root-array")
        }
        throw ValidationFailure.notJSONRoot
    }

    guard let root = json as? [String: Any] else {
        throw ValidationFailure.notJSONRoot
    }

    if root["app"] == nil, root["kind"] == nil, let chats = root["chats"] as? [[String: Any]], !chats.isEmpty {
        throw ValidationFailure.looseShapeDetected("object-with-chats")
    }

    if root["app"] == nil, root["kind"] == nil, looksLikeChatEntry(root) {
        throw ValidationFailure.looseShapeDetected("single-entry")
    }

    let app = trimmedString(root["app"])
    guard app == "BubblePath" else {
        throw ValidationFailure.wrongApp(app)
    }

    let kind = trimmedString(root["kind"])
    guard kind == "chat-history-batch" else {
        throw ValidationFailure.wrongKind(kind)
    }

    let version = root["version"] as? Int
    guard version == 1 else {
        throw ValidationFailure.wrongVersion(version)
    }

    if let sourceApp = root["sourceApp"], trimmedString(sourceApp) == nil {
        throw ValidationFailure.invalidTopLevelField(field: "sourceApp", expectation: "a non-empty string")
    }

    if let sourceChatTitle = root["sourceChatTitle"], trimmedString(sourceChatTitle) == nil {
        throw ValidationFailure.invalidTopLevelField(field: "sourceChatTitle", expectation: "a non-empty string")
    }

    if let sourceChatID = root["sourceChatID"], trimmedString(sourceChatID) == nil {
        throw ValidationFailure.invalidTopLevelField(field: "sourceChatID", expectation: "a non-empty string")
    }

    if let sourceURL = root["sourceURL"] {
        guard let trimmedSourceURL = trimmedString(sourceURL) else {
            throw ValidationFailure.invalidTopLevelField(field: "sourceURL", expectation: "a non-empty string URL")
        }
        guard URL(string: trimmedSourceURL) != nil else {
            throw ValidationFailure.invalidTopLevelSourceURL(trimmedSourceURL)
        }
    }

    guard let chats = root["chats"] as? [[String: Any]] else {
        throw ValidationFailure.missingChats
    }

    guard !chats.isEmpty else {
        throw ValidationFailure.emptyChats
    }

    for (index, entry) in chats.enumerated() {
        try validateChatEntry(entry, index: index)
    }

    let titledConversationCount = Set(chats.compactMap { trimmedString($0["sourceChatTitle"]) }).count
    let idConversationCount = Set(chats.compactMap { trimmedString($0["sourceChatID"]) }).count
    let batchTitle = trimmedString(root["sourceChatTitle"])
    let sourceApp = trimmedString(root["sourceApp"])

    return """
    Valid BubblePath chat-history batch.
    JSON source: \(extraction.extractionKind.rawValue)
    Skipped earlier unrelated JSON: \(extraction.skippedEarlierJSONNoise ? "yes" : "no")
    Entries: \(chats.count)
    Conversation titles: \(titledConversationCount)
    Conversation IDs: \(idConversationCount)
    Batch title: \(batchTitle ?? "none")
    Source app: \(sourceApp ?? "none")
    """
}

do {
    guard CommandLine.arguments.count >= 2 else {
        throw ValidationFailure.usage
    }

    let urls = CommandLine.arguments.dropFirst().map(URL.init(fileURLWithPath:))
    var validCount = 0
    var failures: [(String, String)] = []

    for (index, url) in urls.enumerated() {
        let summary: String
        do {
            summary = try validate(url: url)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            failures.append((url.lastPathComponent, message))
            continue
        }
        if index > 0 {
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
        FileHandle.standardOutput.write(Data(("File: \(url.lastPathComponent)\n").utf8))
        FileHandle.standardOutput.write(Data((summary + "\n").utf8))
        validCount += 1
    }

    if !failures.isEmpty {
        FileHandle.standardOutput.write(Data("\n".utf8))
        for failure in failures {
            FileHandle.standardError.write(Data(("File: \(failure.0)\n").utf8))
            FileHandle.standardError.write(Data(("Validation failed: \(failure.1)\n").utf8))
        }
    }

    if urls.count > 1 || !failures.isEmpty {
        FileHandle.standardOutput.write(Data(("\nValidated \(validCount) chat-history batch file\(validCount == 1 ? "" : "s").\n").utf8))
        if !failures.isEmpty {
            FileHandle.standardError.write(Data(("Failed \(failures.count) chat-history batch file\(failures.count == 1 ? "" : "s").\n").utf8))
        }
    }

    exit(failures.isEmpty ? EXIT_SUCCESS : EXIT_FAILURE)
} catch {
    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    FileHandle.standardError.write(Data(("Validation failed: \(message)\n").utf8))
    exit(EXIT_FAILURE)
}
