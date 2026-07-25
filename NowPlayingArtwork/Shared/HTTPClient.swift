import Foundation

enum HTTPClientError: LocalizedError {
    case invalidResponse
    case statusCode(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."
        case .statusCode(let code, let message):
            return message.isEmpty ? "The server returned HTTP \(code)." : "HTTP \(code): \(message)"
        }
    }
}

enum HTTPClient {
    static func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }
        return (data, httpResponse)
    }

    static func sendValidated(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await send(request)
        guard (200..<300).contains(response.statusCode) else {
            let message = String(data: data.prefix(1_024), encoding: .utf8) ?? ""
            throw HTTPClientError.statusCode(response.statusCode, message)
        }
        return data
    }

    static func formRequest(
        url: URL,
        values: [String: String],
        authorization: String? = nil
    ) -> URLRequest {
        var components = URLComponents()
        components.queryItems = values.map { URLQueryItem(name: $0.key, value: $0.value) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        request.setValue(
            "application/x-www-form-urlencoded; charset=utf-8",
            forHTTPHeaderField: "Content-Type"
        )
        if let authorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    static func bearerRequest(url: URL, accessToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("NowPlayingArtwork/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        return request
    }
}
