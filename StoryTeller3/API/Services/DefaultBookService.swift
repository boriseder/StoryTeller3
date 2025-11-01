import Foundation

class DefaultBookService: BookServiceProtocol {
    private let config: APIConfig
    private let networkService: NetworkService
    private let converter: BookConverterProtocol
    private let rateLimiter: RateLimiter
    
    init(config: APIConfig, networkService: NetworkService, converter: BookConverterProtocol, rateLimiter: RateLimiter) {
        self.config = config
        self.networkService = networkService
        self.converter = converter
        self.rateLimiter = rateLimiter
    }
    
    func fetchBooks(libraryId: String, limit: Int, collapseSeries: Bool) async throws -> [Book] {
        await rateLimiter.waitIfNeeded()
        
        var components = URLComponents(string: "\(config.baseURL)/api/libraries/\(libraryId)/items")!
        var queryItems: [URLQueryItem] = []
        
        if limit > 0 {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }
        
        queryItems.append(URLQueryItem(name: "collapseseries", value: collapseSeries ? "1" : "0"))
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw AudiobookshelfError.invalidURL("\(config.baseURL)/api/libraries/\(libraryId)/items")
        }
        
        AppLogger.general.debug("[BookService] Fetching books from URL: \(url)")
        AppLogger.general.debug("[BookService] collapseseries: \(collapseSeries)")
        
        let request = networkService.createAuthenticatedRequest(url: url, authToken: config.authToken)
        let response: LibraryItemsResponse = try await networkService.performRequest(request, responseType: LibraryItemsResponse.self)
        
        return response.results.compactMap { item in
            converter.convertLibraryItemToBook(item)
        }
    }
    
    func fetchBookDetails(bookId: String, retryCount: Int = 3) async throws -> Book {
        var lastError: Error?
        
        for attempt in 0..<retryCount {
            do {
                guard let url = URL(string: "\(config.baseURL)/api/items/\(bookId)") else {
                    throw AudiobookshelfError.invalidURL("\(config.baseURL)/api/items/\(bookId)")
                }
                
                let request = networkService.createAuthenticatedRequest(url: url, authToken: config.authToken)
                let item: LibraryItem = try await networkService.performRequest(request, responseType: LibraryItem.self)
                
                // DEBUG: Dekodiertes Objekt prüfen
                AppLogger.network.debug("########### Decoded coverPath: \(item.media.coverPath ?? "NIL")")

                guard let book = converter.convertLibraryItemToBook(item) else {
                    throw AudiobookshelfError.bookNotFound(bookId)
                }
                
                
                
                return book
                
            } catch let urlError as URLError where urlError.code == .timedOut || urlError.code == .networkConnectionLost {
                lastError = urlError
                
                if attempt < retryCount - 1 {
                    let delay = pow(2.0, Double(attempt)) * 0.5
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    AppLogger.general.debug("[BookService] Retrying fetchBookDetails, attempt \(attempt + 2)/\(retryCount)")
                    continue
                }
            } catch {
                throw error
            }
        }
        
        throw lastError ?? AudiobookshelfError.networkError(URLError(.timedOut))
    }
}
