import Foundation

// MARK: - Repository Protocol
protocol BookRepositoryProtocol {
    func fetchBooks(libraryId: String, collapseSeries: Bool) async throws -> [Book]
    func fetchBookDetails(bookId: String) async throws -> Book
    func searchBooks(libraryId: String, query: String) async throws -> [Book]
    func fetchSeries(libraryId: String) async throws -> [Series]
    func fetchSeriesBooks(libraryId: String, seriesId: String) async throws -> [Book]
    func fetchPersonalizedSections(libraryId: String) async throws -> [PersonalizedSection]
}

// MARK: - Repository Errors
enum RepositoryError: LocalizedError {
    case networkError(Error)
    case decodingError(Error)
    case notFound
    case invalidData
    case unauthorized
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        case .notFound:
            return "Resource not found"
        case .invalidData:
            return "Invalid or corrupted data"
        case .unauthorized:
            return "Authentication required"
        case .serverError(let code):
            return "Server error (code: \(code))"
        }
    }
}

// MARK: - Book Repository Implementation
class BookRepository: BookRepositoryProtocol {
    
    private let api: AudiobookshelfAPI
    private let cache: BookCacheProtocol?
    
    init(api: AudiobookshelfAPI, cache: BookCacheProtocol? = nil) {
        self.api = api
        self.cache = cache
    }
    
    // MARK: - Public Methods
    
    func fetchBooks(libraryId: String, collapseSeries: Bool) async throws -> [Book] {
        do {
            let books = try await api.fetchBooks(
                from: libraryId,
                limit: 0,
                collapseSeries: collapseSeries
            )
            
            cache?.cacheBooks(books, for: libraryId)
            
            AppLogger.general.debug("[BookRepository] Fetched \(books.count) books from library \(libraryId)")
            
            return books
            
        } catch let decodingError as DecodingError {
            AppLogger.general.debug("[BookRepository] Decoding error: \(decodingError)")
            
            if let cachedBooks = cache?.getCachedBooks(for: libraryId) {
                AppLogger.general.debug("[BookRepository] Returning \(cachedBooks.count) cached books")
                return cachedBooks
            }
            
            throw RepositoryError.decodingError(decodingError)
            
        } catch let urlError as URLError {
            AppLogger.general.debug("[BookRepository] Network error: \(urlError)")
            
            if let cachedBooks = cache?.getCachedBooks(for: libraryId) {
                AppLogger.general.debug("[BookRepository] Returning \(cachedBooks.count) cached books (offline)")
                return cachedBooks
            }
            
            throw RepositoryError.networkError(urlError)
            
        } catch {
            throw RepositoryError.networkError(error)
        }
    }
    
    func fetchBookDetails(bookId: String) async throws -> Book {
        do {
            let book = try await api.fetchBookDetails(bookId: bookId)
            
            cache?.cacheBook(book)
            
            AppLogger.general.debug("[BookRepository] Fetched details for book: \(book.title)")
            
            return book
            
        } catch let decodingError as DecodingError {
            AppLogger.general.debug("[BookRepository] Decoding error for book \(bookId): \(decodingError)")
            
            if let cachedBook = cache?.getCachedBook(bookId: bookId) {
                AppLogger.general.debug("[BookRepository] Returning cached book")
                return cachedBook
            }
            
            throw RepositoryError.decodingError(decodingError)
            
        } catch let urlError as URLError {
            if let cachedBook = cache?.getCachedBook(bookId: bookId) {
                AppLogger.general.debug("[BookRepository] Returning cached book (offline)")
                return cachedBook
            }
            
            throw RepositoryError.networkError(urlError)
            
        } catch {
            throw RepositoryError.networkError(error)
        }
    }
    
    func searchBooks(libraryId: String, query: String) async throws -> [Book] {
        guard !query.isEmpty else {
            return []
        }
        
        do {
            let allBooks = try await fetchBooks(libraryId: libraryId, collapseSeries: false)
            
            let filteredBooks = allBooks.filter { book in
                book.title.localizedCaseInsensitiveContains(query) ||
                (book.author?.localizedCaseInsensitiveContains(query) ?? false)
            }
            
            AppLogger.general.debug("[BookRepository] Search '\(query)' found \(filteredBooks.count) books")
            
            return filteredBooks
            
        } catch {
            throw error
        }
    }
    
    func fetchSeries(libraryId: String) async throws -> [Series] {
        do {
            let series = try await api.fetchSeries(from: libraryId)
            
            AppLogger.general.debug("[BookRepository] Fetched \(series.count) series")
            
            return series
            
        } catch let decodingError as DecodingError {
            throw RepositoryError.decodingError(decodingError)
            
        } catch let urlError as URLError {
            throw RepositoryError.networkError(urlError)
            
        } catch {
            throw RepositoryError.networkError(error)
        }
    }
    
    func fetchSeriesBooks(libraryId: String, seriesId: String) async throws -> [Book] {
        do {
            let books = try await api.fetchSeriesSingle(from: libraryId, seriesId: seriesId)
            
            AppLogger.general.debug("[BookRepository] Fetched \(books.count) books for series \(seriesId)")
            
            return books
            
        } catch let decodingError as DecodingError {
            throw RepositoryError.decodingError(decodingError)
            
        } catch let urlError as URLError {
            throw RepositoryError.networkError(urlError)
            
        } catch {
            throw RepositoryError.networkError(error)
        }
    }
    
    func fetchPersonalizedSections(libraryId: String) async throws -> [PersonalizedSection] {
        do {
            let sections = try await api.fetchPersonalizedSections(from: libraryId)
            
            AppLogger.general.debug("[BookRepository] Fetched \(sections.count) personalized sections")
            
            return sections
            
        } catch let decodingError as DecodingError {
            throw RepositoryError.decodingError(decodingError)
            
        } catch let urlError as URLError {
            throw RepositoryError.networkError(urlError)
            
        } catch {
            throw RepositoryError.networkError(error)
        }
    }
}

// MARK: - Book Cache Protocol
protocol BookCacheProtocol {
    func cacheBooks(_ books: [Book], for libraryId: String)
    func cacheBook(_ book: Book)
    func getCachedBooks(for libraryId: String) -> [Book]?
    func getCachedBook(bookId: String) -> Book?
    func clearCache()
}

// MARK: - Simple In-Memory Cache Implementation
class BookCache: BookCacheProtocol {
    private var booksCache: [String: [Book]] = [:]
    private var bookDetailsCache: [String: Book] = [:]
    private let cacheQueue = DispatchQueue(label: "com.storyteller3.bookcache")
    
    func cacheBooks(_ books: [Book], for libraryId: String) {
        cacheQueue.async {
            self.booksCache[libraryId] = books
        }
    }
    
    func cacheBook(_ book: Book) {
        cacheQueue.async {
            self.bookDetailsCache[book.id] = book
        }
    }
    
    func getCachedBooks(for libraryId: String) -> [Book]? {
        cacheQueue.sync {
            booksCache[libraryId]
        }
    }
    
    func getCachedBook(bookId: String) -> Book? {
        cacheQueue.sync {
            bookDetailsCache[bookId]
        }
    }
    
    func clearCache() {
        cacheQueue.async {
            self.booksCache.removeAll()
            self.bookDetailsCache.removeAll()
        }
    }
}
