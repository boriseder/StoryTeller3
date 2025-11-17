import Foundation

protocol SeriesServiceProtocol {
    func fetchSeries(libraryId: String, limit: Int) async throws -> [Series]
    func fetchSeriesBooks(libraryId: String, seriesId: String) async throws -> [Book]
}
