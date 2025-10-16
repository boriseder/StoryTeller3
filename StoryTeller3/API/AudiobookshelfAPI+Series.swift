import Foundation

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
            AppLogger.general.debug("fetchSeries error: \(error)")
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
                
        let request = networkService.createAuthenticatedRequest(url: url, authToken: authToken)
        
        do {
            // CORRECTED: Use LibraryItemsResponse (not SeriesResponse)
            let response: LibraryItemsResponse = try await networkService.performRequest(
                request,
                responseType: LibraryItemsResponse.self
            )
            
            AppLogger.general.debug("=== fetchSeriesSingle found \(response.results.count) books")
            
            // Convert LibraryItems to Books
            let books = response.results.compactMap { convertLibraryItemToBook($0) }

            // Smart sorting by book number (moved to BookSortHelpers)
            return BookSortHelpers.sortByBookNumber(books)
            
        } catch {
            AppLogger.general.debug("❌ fetchSeriesSingle error: \(error)")
            throw error
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func encodeSeriesId(_ seriesId: String) -> String {
        guard let data = seriesId.data(using: .utf8) else {
            AppLogger.general.debug("⚠️ Failed to encode series ID to UTF-8: \(seriesId)")
            return seriesId // Fallback
        }
        
        // Base64 URL-safe encoding
        let base64 = data.base64EncodedString()
        
        // Convert to URL-safe characters
        let urlSafe = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "") // Remove padding
        
        AppLogger.general.debug("🔄 Series ID encoding: '\(seriesId)' → '\(urlSafe)'")
        
        return urlSafe
    }

}
