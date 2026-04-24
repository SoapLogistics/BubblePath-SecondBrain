import Foundation

struct OpenAIClient {
    var apiKeyProvider: () -> String?
    var model: String
    var guidePrompt: String

    func respond(
        to bubble: Bubble,
        userPrompt: String,
        linkedBubbles: [Bubble],
        recentMessages: [BubbleMessage]
    ) async throws -> String {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        let linkedText = linkedBubbles
            .map { "- \($0.type.rawValue): \($0.displayTitle) :: \($0.displayBody)" }
            .joined(separator: "\n")

        let history: [ResponsesInput] = recentMessages.compactMap { message in
            guard message.role != .note else { return nil }
            return ResponsesInput(
                role: message.role == .assistant ? "assistant" : "user",
                content: message.text
            )
        }

        let requestBody = ResponsesRequest(
            model: model,
            instructions: guidePrompt,
            input: [
                ResponsesInput(
                    role: "user",
                    content: """
                    Use this BubblePath context while answering.

                    Current bubble type: \(bubble.type.rawValue)
                    Current bubble title: \(bubble.displayTitle)
                    Current bubble body:
                    \(bubble.displayBody.isEmpty ? "No body text yet." : bubble.displayBody)

                    Memory scope: \(bubble.memoryScope.label)

                    Connected bubbles:
                    \(linkedText.isEmpty ? "None yet." : linkedText)

                    User prompt: \(userPrompt)
                    """
                )
            ] + history + [
                ResponsesInput(role: "user", content: userPrompt)
            ]
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OpenAIError.requestFailed("No HTTP response was returned.")
        }
        guard 200..<300 ~= http.statusCode else {
            let apiError = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            throw OpenAIError.requestFailed(apiError?.error.message ?? "The OpenAI request did not succeed.")
        }

        let decoded = try JSONDecoder().decode(ResponsesResponse.self, from: data)
        return decoded.outputText
    }
}

enum OpenAIError: Error {
    case missingAPIKey
    case requestFailed(String)
}

extension OpenAIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add and save an OpenAI API key first."
        case .requestFailed(let message):
            if message.localizedCaseInsensitiveContains("quota") ||
                message.localizedCaseInsensitiveContains("billing") {
                return "Your key is connected, but the API account does not have usable quota right now. Check platform billing and usage."
            }
            return message
        }
    }
}

private struct ResponsesRequest: Encodable {
    var model: String
    var instructions: String
    var input: [ResponsesInput]
}

private struct ResponsesInput: Encodable {
    var role: String
    var content: String
}

private struct ResponsesResponse: Decodable {
    var output: [ResponsesOutput]?
    var outputText: String {
        output?
            .flatMap { $0.content ?? [] }
            .compactMap { item in
                item.type == "output_text" ? item.text : nil
            }
            .joined(separator: "\n") ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case output
    }
}

private struct ResponsesOutput: Decodable {
    var content: [ResponsesContent]?
}

private struct ResponsesContent: Decodable {
    var type: String
    var text: String?
}

private struct OpenAIErrorResponse: Decodable {
    struct APIError: Decodable {
        var message: String
    }

    var error: APIError
}
