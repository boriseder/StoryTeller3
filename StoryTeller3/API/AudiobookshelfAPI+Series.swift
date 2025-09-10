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
