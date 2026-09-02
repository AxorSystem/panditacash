import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case http(Int, String)
    case decoding(Error)
    case transport(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL: "URL inválida"
        case .http(let c, let m): "Error \(c): \(m)"
        case .decoding(let e): "Respuesta inesperada: \(e.localizedDescription)"
        case .transport(let e): "Sin conexión: \(e.localizedDescription)"
        case .unauthorized: "Sesión expirada"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    let baseURL = URL(string: "https://api-panditacash.axorcloud.com/api")!
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // Sin keyDecodingStrategy: conflictúa con CodingKeys manuales.
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()
    var tokenProvider: () -> String? = { nil }
    var onUnauthorized: () -> Void = {}

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        try await request(path: path, method: "GET", query: query, body: Optional<String>.none)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await request(path: path, method: "POST", body: body)
    }

    func postNoBody<T: Decodable>(_ path: String) async throws -> T {
        try await request(path: path, method: "POST", body: Optional<String>.none)
    }

    func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await request(path: path, method: "PATCH", body: body)
    }

    func put<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await request(path: path, method: "PUT", body: body)
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        try await request(path: path, method: "DELETE", body: Optional<String>.none)
    }

    private func request<B: Encodable, T: Decodable>(
        path: String, method: String, query: [String: String] = [:], body: B?
    ) async throws -> T {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            comps?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = comps?.url else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = tokenProvider() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try encoder.encode(body)
        }
        req.timeoutInterval = 20
        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await URLSession.shared.data(for: req) }
        catch { throw APIError.transport(error) }
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.http(-1, "Sin respuesta")
        }
        if http.statusCode == 401 {
            onUnauthorized()
            throw APIError.unauthorized
        }
        if !(200..<300).contains(http.statusCode) {
            let msg = extractMessage(data: data) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.http(http.statusCode, msg)
        }
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding(error) }
    }

    private func extractMessage(data: Data) -> String? {
        struct Err: Decodable { let error: String? }
        return (try? JSONDecoder().decode(Err.self, from: data))?.error
    }
}

struct EmptyResponse: Decodable {}
