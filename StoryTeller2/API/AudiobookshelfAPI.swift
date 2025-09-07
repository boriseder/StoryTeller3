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
    
    // MARK: - Books
    func fetchBooks(from libraryId: String, limit: Int = 50) async throws -> [Book] {
        guard let url = URL(string: "\(baseURLString)/api/libraries/\(libraryId)/items?limit=\(limit)") else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/libraries/\(libraryId)/items")
        }
        
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
    private func convertLibraryItemToBook(_ item: LibraryItem) -> Book? {
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
            coverPath: item.coverPath
        )
    }
}
