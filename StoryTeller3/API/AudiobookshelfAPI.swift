import Foundation

// MARK: - Connection Test Result
enum ConnectionTestResult {
    case success
    case serverFoundButUnauthorized
    case failed
}

// MARK: - Main API Client
class AudiobookshelfAPI {
    
    // MARK: - Properties
    let baseURLString: String
    let authToken: String
    internal let networkService: NetworkService
    private let rateLimiter = RateLimiter(minimumInterval: 0.1) // 10 requests/second max

    // MARK: - Initialization
    init(baseURL: String, apiKey: String, networkService: NetworkService = DefaultNetworkService()) {
        self.baseURLString = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.authToken = apiKey
        self.networkService = networkService
    }
    
    // MARK: - Connection Testing
    func testConnection() async throws -> ConnectionTestResult {
        guard let url = URL(string: "\(baseURLString)/api/libraries") else {
            throw AudiobookshelfError.invalidURL(baseURLString)
        }
        
        let request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
        
        do {
            let _: LibrariesResponse = try await networkService.performRequest(request, responseType: LibrariesResponse.self)
            return .success
        } catch AudiobookshelfError.unauthorized {
            // Try without auth to see if server exists
            var unauthenticatedRequest = URLRequest(url: url)
            unauthenticatedRequest.timeoutInterval = 10.0
            
            do {
                let (_, response) = try await URLSession.shared.data(for: unauthenticatedRequest)
                if let httpResponse = response as? HTTPURLResponse {
                    return httpResponse.statusCode == 401 ? .serverFoundButUnauthorized : .failed
                }
            } catch {
                return .failed
            }
            
            return .failed
        } catch {
            return .failed
        }
    }
    
    // MARK: - Libraries
    func fetchLibraries() async throws -> [Library] {
        guard let url = URL(string: "\(baseURLString)/api/libraries") else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/libraries")
        }
        
        let request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
        let response: LibrariesResponse = try await networkService.performRequest(request, responseType: LibrariesResponse.self)
        
        return response.libraries.filter { $0.isAudiobook }
    }
    
    // MARK: - Books
    func fetchBooks(from libraryId: String, limit: Int = 0, collapseSeries: Bool = false) async throws -> [Book] {
        await rateLimiter.waitIfNeeded()

        // URL mit Query-Parametern erstellen
        var components = URLComponents(string: "\(baseURLString)/api/libraries/\(libraryId)/items")!
        var queryItems: [URLQueryItem] = []
        
        if limit > 0 {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }
        
        // collapseSeries Parameter hinzufügen
        queryItems.append(URLQueryItem(name: "collapseseries", value: collapseSeries ? "1" : "0"))
        
        components.queryItems = queryItems
        
        components.queryItems = queryItems

        guard let url = components.url else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/libraries/\(libraryId)/items")
        }

        AppLogger.debug.debug("[AudiobookshelfAPI] URL \(url)")
        AppLogger.debug.debug("[AudiobookshelfAPI] collapsesseries  \(collapseSeries)")

        let request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
        let response: LibraryItemsResponse = try await networkService.performRequest(request, responseType: LibraryItemsResponse.self)
        
        return response.results.compactMap { item in
            convertLibraryItemToBook(item)
        }
    }
    
    func fetchBookDetails(bookId: String, retryCount: Int = 3) async throws -> Book {
        var lastError: Error?
        
        for attempt in 0..<retryCount {
            do {
                guard let url = URL(string: "\(baseURLString)/api/items/\(bookId)") else {
                    throw AudiobookshelfError.invalidURL("\(baseURLString)/api/items/\(bookId)")
                }
                
                let request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
                let item: LibraryItem = try await networkService.performRequest(request, responseType: LibraryItem.self)
                
                guard let book = convertLibraryItemToBook(item) else {
                    throw AudiobookshelfError.bookNotFound(bookId)
                }
                
                return book
                
            } catch let urlError as URLError where urlError.code == .timedOut || urlError.code == .networkConnectionLost {
                lastError = urlError
                
                if attempt < retryCount - 1 {
                    // Exponential backoff
                    let delay = pow(2.0, Double(attempt)) * 0.5
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    AppLogger.debug.debug("[AudiobookshelfAPI] Retrying fetchBookDetails, attempt \(attempt + 2)/\(retryCount)")
                    continue
                }
            } catch {
                throw error
            }
        }
        
        throw lastError ?? AudiobookshelfError.networkError(URLError(.timedOut))
    }
    
    // MARK: - Library Statistics
    
    func fetchLibraryStats(libraryId: String) async throws -> Int {
        guard let url = URL(string: "\(baseURLString)/api/libraries/\(libraryId)/items?limit=1") else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/libraries/\(libraryId)/items")
        }
        
        let request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
        let response: LibraryItemsResponse = try await networkService.performRequest(
            request,
            responseType: LibraryItemsResponse.self
        )
        
        AppLogger.debug.debug("[AudiobookshelfAPI] Library \(libraryId) has \(response.total ?? 0) total books")
        
        return response.total ?? 0
    }
    // MARK: - Progress Sync
    
    func syncSessionProgress(
        sessionId: String,
        currentTime: Double,
        timeListened: Double,
        duration: Double
    ) async throws {
        guard let url = URL(string: "\(baseURLString)/api/session/\(sessionId)/sync") else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/session/\(sessionId)/sync")
        }
        
        let body: [String: Any] = [
            "currentTime": currentTime,
            "timeListened": timeListened,
            "duration": duration
        ]
        
        var request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw AudiobookshelfError.invalidRequest(error.localizedDescription)
        }
        
        AppLogger.debug.debug("[AudiobookshelfAPI] Syncing session progress: \(sessionId), time: \(currentTime)s")
        
        // Use performRequest but ignore response since PATCH /sync returns session data we don't need
        let _: [String: String]? = try? await networkService.performRequest(request, responseType: [String: String].self)
    }

    func fetchProgress(for libraryItemId: String) async throws -> MediaProgress? {
        guard let url = URL(string: "\(baseURLString)/api/me/progress/\(libraryItemId)") else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/me/progress/\(libraryItemId)")
        }
        
        let request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
        
        AppLogger.debug.debug("[AudiobookshelfAPI] Fetching progress for item: \(libraryItemId)")
        
        do {
            let progress: MediaProgress = try await networkService.performRequest(request, responseType: MediaProgress.self)
            return progress
        } catch AudiobookshelfError.resourceNotFound {
            // No progress exists yet - this is normal for items not started
            AppLogger.debug.debug("[AudiobookshelfAPI] No progress found for item: \(libraryItemId)")
            return nil
        }
    }
    
    func closeSession(
        sessionId: String,
        currentTime: Double,
        timeListened: Double
    ) async throws {
        guard let url = URL(string: "\(baseURLString)/api/session/\(sessionId)/close") else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/session/\(sessionId)/close")
        }
        
        let body: [String: Any] = [
            "currentTime": currentTime,
            "timeListened": timeListened
        ]
        
        var request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw AudiobookshelfError.invalidRequest(error.localizedDescription)
        }
        
        AppLogger.debug.debug("[AudiobookshelfAPI] Closing session: \(sessionId), final time: \(currentTime)s")
        
        let _: [String: String]? = try? await networkService.performRequest(request, responseType: [String: String].self)
    }

    func fetchItemsInProgress() async throws -> [MediaProgress] {
        guard let url = URL(string: "\(baseURLString)/api/me/items-in-progress") else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/me/items-in-progress")
        }
        
        let request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
        
        AppLogger.debug.debug("[AudiobookshelfAPI] Fetching items in progress")
        
        struct ItemsInProgressResponse: Codable {
            let libraryItems: [MediaProgress]
        }
        
        let response: ItemsInProgressResponse = try await networkService.performRequest(request, responseType: ItemsInProgressResponse.self)
        return response.libraryItems
    }
    
    // MARK: - Conversion Helper
    public func convertLibraryItemToBook(_ item: LibraryItem) -> Book? {
        // Create chapters from media tracks or use provided chapters
        let chapters: [Chapter] = {
            if let mediaChapters = item.media.chapters, !mediaChapters.isEmpty {
                return mediaChapters.map { chapter in
                    Chapter(
                        id: chapter.id,
                        title: chapter.title,
                        start: chapter.start,
                        end: chapter.end,
                        libraryItemId: item.id,
                        episodeId: chapter.episodeId
                    )
                }
            } else if let tracks = item.media.tracks, !tracks.isEmpty {
                // Create chapters from tracks if no chapters exist
                return tracks.enumerated().map { index, track in
                    Chapter(
                        id: "\(index)",
                        title: track.title ?? "Kapitel \(index + 1)",
                        start: track.startOffset,
                        end: track.startOffset + track.duration,
                        libraryItemId: item.id
                    )
                }
            } else {
                // Fallback: create a single chapter for the whole book
                return [Chapter(
                    id: "0",
                    title: item.media.metadata.title,
                    start: 0,
                    end: item.media.duration ?? 3600,
                    libraryItemId: item.id
                )]
            }
        }()
        
        return Book(
            id: item.id,
            title: item.media.metadata.title,
            author: item.media.metadata.author,
            chapters: chapters,
            coverPath: item.coverPath,
            collapsedSeries: item.collapsedSeries
        )
    }
    
    func checkConnectionHealth() async -> Bool {
        guard let url = URL(string: "\(baseURLString)/ping") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0 // Shorter timeout for health check
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }

}


