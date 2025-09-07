import Foundation

// MARK: - Network Layer
protocol NetworkService {
    func performRequest<T: Decodable>(_ request: URLRequest, responseType: T.Type) async throws -> T
    func createAuthenticatedRequest(url: URL, authToken: String) -> URLRequest
}

class DefaultNetworkService: NetworkService {
    private let urlSession: URLSession
    
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    func performRequest<T: Decodable>(_ request: URLRequest, responseType: T.Type) async throws -> T {
        do {
            let (data, response) = try await urlSession.data(for: request)
            try validateResponse(response, data: data)
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as AudiobookshelfError {
            throw error
        } catch let decodingError as DecodingError {
            throw AudiobookshelfError.decodingError(decodingError)
        } catch {
            throw AudiobookshelfError.networkError(error)
        }
    }
    
    func createAuthenticatedRequest(url: URL, authToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0
        return request
    }
    
    private func validateResponse(_ response: URLResponse?, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AudiobookshelfError.noData
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw AudiobookshelfError.unauthorized
        case 404:
            throw AudiobookshelfError.noData
        default:
            let errorMessage = String(data: data, encoding: .utf8)
            throw AudiobookshelfError.serverError(httpResponse.statusCode, errorMessage)
        }
    }
}
