import FirebaseAuth
import Foundation

/// `APIClient` is the single, shared HTTP entry point. Every concrete service
/// (`APIVideoService`, `APIProfileService`, etc.) uses `APIClient.shared` to
/// avoid duplicating URL construction, auth header handling, and JSON
/// encoding/decoding logic.
///
/// What it does for callers:
///   - Builds full URLs from a relative `path` plus optional query params.
///   - Attaches the current Firebase ID token as `Authorization: Bearer …`
///     so the backend can identify the caller. We refresh the token on
///     every request — Firebase caches the live token internally so this
///     is cheap, but it guarantees we never send an expired one.
///   - Encodes Swift `Codable` bodies to JSON with ISO-8601 dates.
///   - Decodes responses with a custom date strategy that accepts both
///     fractional-second and second-resolution timestamps.
///   - Translates non-2xx responses into `APIError` values with the response
///     body for easier debugging.
///
/// Thread safety: `URLSession` is concurrency-safe; the JSONEncoder/Decoder
/// instances are accessed on the calling task, which is fine because Swift
/// concurrency disallows simultaneous access to the same instance unless we
/// explicitly opt in.

/// `APIError` is the only error type the rest of the app needs to catch when
/// dealing with the network layer. Its associated values carry enough
/// context to render a useful diagnostic in DEBUG and a friendly message in
/// production.
enum APIError: LocalizedError {
    case invalidURL
    case badResponse(statusCode: Int, body: String)
    case decodingFailed(underlying: Error)
    case networkError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .badResponse(let code, let body):
            return "Server error \(code): \(body)"
        case .decodingFailed(let err):
            return "Decoding error: \(err.localizedDescription)"
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    let baseURL = "https://tape-cf2k.onrender.com"

    private let session: URLSession
    let decoder: JSONDecoder
    let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFractional.date(from: dateString) {
                return date
            }

            let withoutFractional = ISO8601DateFormatter()
            withoutFractional.formatOptions = [.withInternetDateTime]
            if let date = withoutFractional.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        let url = try buildURL(path: path, query: query)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try await attachAuthToken(to: &request)
        return try await perform(request)
    }

    func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        try await attachAuthToken(to: &request)
        return try await perform(request)
    }

    func put<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        try await attachAuthToken(to: &request)
        return try await perform(request)
    }

    func putEmpty<T: Decodable>(_ path: String) async throws -> T {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        try await attachAuthToken(to: &request)
        return try await perform(request)
    }

    func patch<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        try await attachAuthToken(to: &request)
        return try await perform(request)
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        try await attachAuthToken(to: &request)
        return try await perform(request)
    }

    /// DELETE that ignores the response body (server may return 204 No Content
    /// or an empty 200). Use this when the backend confirms deletion by status
    /// code rather than by echoing the deleted resource.
    func deleteVoid(_ path: String) async throws {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        try await attachAuthToken(to: &request)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidURL }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.badResponse(
                statusCode: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }
    }

    func postVoid(_ path: String, body: some Encodable) async throws {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        try await attachAuthToken(to: &request)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidURL }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.badResponse(
                statusCode: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }
    }

    // MARK: - Auth

    private func attachAuthToken(to request: inout URLRequest) async throws {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        let token = try await firebaseUser.getIDToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    // MARK: - Private

    private func buildURL(path: String, query: [String: String] = [:]) throws -> URL {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidURL
        }

        guard (200...299).contains(http.statusCode) else {
            throw APIError.badResponse(
                statusCode: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("API decoding error for \(request.url?.absoluteString ?? "?"): \(error)")
            if let json = String(data: data, encoding: .utf8) {
                print("Response body: \(json.prefix(500))")
            }
            #endif
            throw APIError.decodingFailed(underlying: error)
        }
    }
}
