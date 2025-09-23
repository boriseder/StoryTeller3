import Foundation

// MARK: - Series Models

struct Series: Identifiable {
    let id: String
    let name: String
    let nameIgnorePrefix: String?
    let nameIgnorePrefixSort: String?
    let books: [LibraryItem]
    let addedAt: TimeInterval
    
    // Computed totalDuration from books
    var totalDuration: Double {
        books.reduce(0) { total, book in
            total + (book.media.duration ?? 0)
        }
    }
}

// MARK: - Series Decodable Implementation (nur zum Lesen)
extension Series: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name, nameIgnorePrefix, nameIgnorePrefixSort, books, addedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        nameIgnorePrefix = try container.decodeIfPresent(String.self, forKey: .nameIgnorePrefix)
        nameIgnorePrefixSort = try container.decodeIfPresent(String.self, forKey: .nameIgnorePrefixSort)
        books = try container.decode([LibraryItem].self, forKey: .books)
        addedAt = try container.decode(TimeInterval.self, forKey: .addedAt)
    }
}

// MARK: - Series Computed Properties
extension Series {
    var bookCount: Int { books.count }
    var firstBook: LibraryItem? { books.first }
    var coverPath: String? { firstBook?.coverPath }
    var author: String? { firstBook?.media.metadata.author }
    var formattedDuration: String {
        TimeFormatter.formatTimeCompact(totalDuration)
    }
}

// MARK: - SeriesResponseItem (for API responses)
struct SeriesResponseItem: Decodable {
    let id: String
    let name: String
    let nameIgnorePrefix: String?
    let nameIgnorePrefixSort: String?
    let books: [LibraryItem]
    let addedAt: TimeInterval
    
    // Conversion method to Series
    func toSeries() -> Series {
        return Series(
            id: id,
            name: name,
            nameIgnorePrefix: nameIgnorePrefix,
            nameIgnorePrefixSort: nameIgnorePrefixSort,
            books: books,
            addedAt: addedAt
        )
    }
}

// Update SeriesResponse to use SeriesResponseItem
struct SeriesResponse: Decodable {
    let results: [SeriesResponseItem]  // ✅ Use SeriesResponseItem
    let total: Int
    let limit: Int
    let page: Int
    let sortBy: String?
    let sortDesc: Bool
    let filterBy: String?
    let mediaType: String?
    let minified: Bool
    let collapseseries: Bool?
    let include: String?
}
