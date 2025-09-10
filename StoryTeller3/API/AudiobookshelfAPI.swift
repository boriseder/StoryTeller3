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
    private let networkService: NetworkService
    
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
    
    // MARK: - Books (Debug Version)
    func fetchBooks(from libraryId: String, limit: Int = 0, collapseSeries: Bool = false) async throws -> [Book] {
        
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

        AppLogger.debug.debug("URL \(url)")
        AppLogger.debug.debug("collapsesseries  \(collapseSeries)")

        let request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
        let response: LibraryItemsResponse = try await networkService.performRequest(request, responseType: LibraryItemsResponse.self)
        
        return response.results.compactMap { item in
            convertLibraryItemToBook(item)
        }
    }
    
    func fetchBookDetails(bookId: String) async throws -> Book {
        guard let url = URL(string: "\(baseURLString)/api/items/\(bookId)") else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/items/\(bookId)")
        }
        
        let request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
        let item: LibraryItem = try await networkService.performRequest(request, responseType: LibraryItem.self)
        
        guard let book = convertLibraryItemToBook(item) else {
            throw AudiobookshelfError.bookNotFound(bookId)
        }
        
        return book
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
}

// Add this method to AudiobookshelfAPI.swift

extension AudiobookshelfAPI {
    
    func fetchSeries(from libraryId: String, limit: Int = 1000) async throws -> [Series] {
        guard let url = URL(string: "\(baseURLString)/api/libraries/\(libraryId)/series?limit=\(limit)") else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/libraries/\(libraryId)/series")
        }
        
        let request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
        
        do {
            let response: SeriesResponse = try await networkService.performRequest(request, responseType: SeriesResponse.self)
            return response.results.map { $0.toSeries() }
        } catch {
            AppLogger.debug.debug("fetchSeries error: \(error)")
            throw error
        }
    }
    
    /// Fetch books from a single series
    func fetchSeriesSingle(from libraryId: String, seriesId: String) async throws -> [Book] {
        let encodedSeriesId = encodeSeriesId(seriesId)
        
        var components = URLComponents(string: "\(baseURLString)/api/libraries/\(libraryId)/items")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "1000"),
            URLQueryItem(name: "filter", value: "series.\(encodedSeriesId)")
        ]
        
        guard let url = components.url else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/libraries/\(libraryId)/items")
        }
        
        AppLogger.debug.debug("=== fetchSeriesSingle URL: \(url)")
        
        let request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
        
        do {
            // ✅ CORRECTED: Use LibraryItemsResponse (not SeriesResponse)
            let response: LibraryItemsResponse = try await networkService.performRequest(
                request,
                responseType: LibraryItemsResponse.self
            )
            
            AppLogger.debug.debug("=== fetchSeriesSingle found \(response.results.count) books")
            
            // Convert LibraryItems to Books
            let books = response.results.compactMap { convertLibraryItemToBook($0) }
            
            // Smart sorting by book number
            return books.sorted { book1, book2 in
                return smartBookSort(book1: book1, book2: book2)
            }
            
        } catch {
            AppLogger.debug.debug("❌ fetchSeriesSingle error: \(error)")
            throw error
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func encodeSeriesId(_ seriesId: String) -> String {
        guard let data = seriesId.data(using: .utf8) else {
            AppLogger.debug.debug("⚠️ Failed to encode series ID to UTF-8: \(seriesId)")
            return seriesId // Fallback
        }
        
        // Base64 URL-safe encoding
        let base64 = data.base64EncodedString()
        
        // Convert to URL-safe characters
        let urlSafe = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "") // Remove padding
        
        AppLogger.debug.debug("🔄 Series ID encoding: '\(seriesId)' → '\(urlSafe)'")
        
        return urlSafe
    }

    private func smartBookSort(book1: Book, book2: Book) -> Bool {
        let title1 = book1.title.lowercased()
        let title2 = book2.title.lowercased()
        
        // Try to extract book numbers for natural sorting
        if let num1 = extractBookNumber(from: title1),
           let num2 = extractBookNumber(from: title2) {
            return num1 < num2
        }
        
        // Fallback to alphabetical sorting
        return title1.localizedCompare(title2) == .orderedAscending
    }
    
    private func extractBookNumber(from title: String) -> Int? {
        // Patterns for common book numbering
        let patterns = [
            #"(?:book|part|vol|volume|teil|band)\s*(\d+)"#,
            #"^(\d+)[\.\-\s]"#,
            #"\b(\d+)\b"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(title.startIndex..<title.endIndex, in: title)
                if let match = regex.firstMatch(in: title, options: [], range: range),
                   match.numberOfRanges > 1 {
                    let numberRange = match.range(at: 1)
                    if let swiftRange = Range(numberRange, in: title) {
                        if let number = Int(String(title[swiftRange])) {
                            return number
                        }
                    }
                }
            }
        }
        return nil
    }
}
