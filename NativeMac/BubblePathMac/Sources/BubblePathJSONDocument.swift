import SwiftUI
import UniformTypeIdentifiers

struct BubblePathJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var document: BubblePathDocument

    init(document: BubblePathDocument) {
        self.document = document
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder.bubblePathDecoder
        document = try decoder.decode(BubblePathDocument.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder.bubblePathEncoder
        let data = try encoder.encode(document)
        return .init(regularFileWithContents: data)
    }
}

extension JSONEncoder {
    static var bubblePathEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(BubbleDateCoding.encode(date))
        }
        return encoder
    }
}

extension JSONDecoder {
    static var bubblePathDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = BubbleDateCoding.decode(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO date: \(value)"
            )
        }
        return decoder
    }
}
