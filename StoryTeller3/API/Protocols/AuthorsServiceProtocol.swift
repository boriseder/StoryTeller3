import Foundation

protocol AuthorsServiceProtocol {
    func fetchAuthors(libraryId: String) async throws -> [Author]
    func fetchAuthor(authorId: String, libraryId: String, includeBooks: Bool, includeSeries: Bool) async throws -> Author
}
