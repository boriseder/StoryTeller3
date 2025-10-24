import Foundation

protocol BookServiceProtocol {
    func fetchBooks(libraryId: String, limit: Int, collapseSeries: Bool) async throws -> [Book]
    func fetchBookDetails(bookId: String, retryCount: Int) async throws -> Book
}
