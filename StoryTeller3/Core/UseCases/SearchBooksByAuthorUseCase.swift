import Foundation

/// Use Case for searching books by author name
/// Encapsulates the business logic for author-based book search
protocol SearchBooksByAuthorUseCaseProtocol {
    func execute(libraryId: String, authorName: String) async throws -> [Book]
}

class SearchBooksByAuthorUseCase: SearchBooksByAuthorUseCaseProtocol {
    private let bookRepository: BookRepositoryProtocol
    
    init(bookRepository: BookRepositoryProtocol) {
        self.bookRepository = bookRepository
    }
    
    func execute(libraryId: String, authorName: String) async throws -> [Book] {
        guard !authorName.isEmpty else {
            AppLogger.general.debug("[SearchBooksByAuthorUseCase] Empty author name")
            return []
        }
        
        let allBooks = try await bookRepository.fetchBooks(
            libraryId: libraryId,
            collapseSeries: false
        )
        
        let authorBooks = allBooks.filter { book in
            book.author?.localizedCaseInsensitiveContains(authorName) == true
        }
        
        AppLogger.general.debug("[SearchBooksByAuthorUseCase] Found \(authorBooks.count) books by '\(authorName)'")
        
        return authorBooks
    }
}
