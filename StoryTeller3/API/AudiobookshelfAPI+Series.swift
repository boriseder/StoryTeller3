import Foundation

// MARK: - Series API Extension
extension AudiobookshelfAPI {
    
    // Fetch all series from library
    func fetchSeries(from libraryId: String, limit: Int = 0) async throws -> [Series] {
        guard let url = URL(string: "\(baseURLString)/api/libraries/\(libraryId)/series?limit=\(limit)") else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/libraries/\(libraryId)/series")
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response, data: data)
            let seriesResponse = try JSONDecoder().decode(SeriesResponse.self, from: data)
            return seriesResponse.results
        } catch let error as AudiobookshelfError {
            throw error
        } catch let decodingError as DecodingError {
            throw AudiobookshelfError.decodingError(decodingError)
        } catch {
            throw AudiobookshelfError.networkError(error)
        }
    }
    
    // Fetch single series details
    func fetchSeriesDetails(seriesId: String) async throws -> Series {
        guard let url = URL(string: "\(baseURLString)/api/series/\(seriesId)") else {
            throw AudiobookshelfError.invalidURL("\(baseURLString)/api/series/\(seriesId)")
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response, data: data)
            let series = try JSONDecoder().decode(Series.self, from: data)
            return series
        } catch let error as AudiobookshelfError {
            throw error
        } catch let decodingError as DecodingError {
            throw AudiobookshelfError.decodingError(decodingError)
        } catch {
            throw AudiobookshelfError.networkError(error)
        }
    }
    
    // MARK: - Private Helper (kopiert aus NetworkService)
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
