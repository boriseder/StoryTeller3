import Foundation

struct LibraryFilterState {
    var searchText: String = ""
    var selectedSortOption: LibrarySortOption = .title
    var showDownloadedOnly: Bool = false
    var showSeriesGrouped: Bool = false
    
    func matchesSearchFilter(_ book: Book) -> Bool {
        guard !searchText.isEmpty else { return true }
        
        return book.title.localizedCaseInsensitiveContains(searchText) ||
               (book.author?.localizedCaseInsensitiveContains(searchText) ?? false)
    }
    
    func matchesDownloadFilter(_ book: Book, isDownloaded: Bool) -> Bool {
        guard showDownloadedOnly else { return true }
        return isDownloaded
    }
    
    func applySorting(to books: [Book]) -> [Book] {
        return books.sorted { book1, book2 in
            switch selectedSortOption {
            case .title:
                return book1.title.localizedCompare(book2.title) == .orderedAscending
            case .author:
                return (book1.author ?? "Unbekannt").localizedCompare(book2.author ?? "Unbekannt") == .orderedAscending
            case .recent:
                return book1.id > book2.id
            }
        }
    }
    
    mutating func loadFromDefaults() {
        showDownloadedOnly = UserDefaults.standard.bool(forKey: "library_show_downloaded_only")
        showSeriesGrouped = UserDefaults.standard.bool(forKey: "library_show_series_grouped")
    }
    
    func saveToDefaults() {
        UserDefaults.standard.set(showDownloadedOnly, forKey: "library_show_downloaded_only")
        UserDefaults.standard.set(showSeriesGrouped, forKey: "library_show_series_grouped")
    }
    
    mutating func reset() {
        searchText = ""
        showDownloadedOnly = false
        showSeriesGrouped = false
        saveToDefaults()
    }
}
