import Foundation

// MARK: - Bookmark Model
struct Bookmark: Codable, Identifiable {
    let libraryItemId: String
    let time: Double
    let title: String
    let createdAt: TimeInterval
    
    var id: String {
        "\(libraryItemId)-\(time)-\(createdAt)"
    }
    
    var createdDate: Date {
        Date(timeIntervalSince1970: createdAt / 1000) // Server uses milliseconds
    }
    
    var formattedTime: String {
        TimeFormatter.formatTime(time)
    }
    
    /// Finde das Kapitel, in dem dieser Bookmark liegt
    func chapterIndex(for book: Book) -> Int {
        for (index, chapter) in book.chapters.enumerated() {
            let start = chapter.start ?? 0
            let end = chapter.end ?? Double.greatestFiniteMagnitude
            
            if time >= start && time < end {
                return index
            }
        }
        
        return max(0, book.chapters.count - 1)
    }
    
    /// Kapitel-Name für diesen Bookmark
    func chapterTitle(for book: Book) -> String? {
        let index = chapterIndex(for: book)
        guard index < book.chapters.count else { return nil }
        return book.chapters[index].title
    }
}

// MARK: - User Model Extension
struct UserData: Codable {
    let id: String
    let username: String
    let email: String?
    let type: String
    let token: String
    let mediaProgress: [MediaProgress]
    let bookmarks: [Bookmark]
    
    // Helpers
    func bookmarks(for libraryItemId: String) -> [Bookmark] {
        bookmarks.filter { $0.libraryItemId == libraryItemId }
            .sorted { $0.time < $1.time }
    }
    
    func progress(for libraryItemId: String) -> MediaProgress? {
        mediaProgress.first { $0.libraryItemId == libraryItemId }
    }
}

// MARK: - Enhanced Bookmark Model
struct EnrichedBookmark: Identifiable {
    let bookmark: Bookmark
    let book: Book?
    
    var id: String { bookmark.id }
    var isBookLoaded: Bool { book != nil }
    var displayTitle: String { bookmark.title }
    var bookTitle: String { book?.title ?? "Loading..." }
}

// MARK: - Bookmark Sort Options
enum BookmarkSortOption: String, CaseIterable, Identifiable {
    case dateNewest = "Date (Newest)"
    case dateOldest = "Date (Oldest)"
    case timeInBook = "Time in Book"
    case bookTitle = "Book Title"
    
    var id: String { rawValue }
}
