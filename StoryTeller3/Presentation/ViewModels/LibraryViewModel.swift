//
//  LibraryViewModel.swift
//  StoryTeller3
//
//  Created by Boris Eder on 09.09.25.
//

import SwiftUI

class LibraryViewModel: BaseViewModel {
    @Published var books: [Book] = []
    @Published var searchText = ""
    @Published var selectedSortOption: LibrarySortOption = .title
    @Published var showDownloadedOnly = false // ← Neu hinzugefügt
    @Published var libraryName: String = "Meine Bibliothek"
    
    let api: AudiobookshelfAPI
    let player: AudioPlayer
    let downloadManager: DownloadManager
    private let onBookSelected: () -> Void
    
    var filteredAndSortedBooks: [Book] {
        let filtered = searchText.isEmpty ? books : books.filter { book in
            book.title.localizedCaseInsensitiveContains(searchText) ||
            (book.author?.localizedCaseInsensitiveContains(searchText) ?? false)
        }

        // ← Filter für heruntergeladene Bücher hinzufügen
        let downloadFiltered = showDownloadedOnly ? filtered.filter { book in
            downloadManager.isBookDownloaded(book.id)
        } : filtered

        return downloadFiltered.sorted { book1, book2 in
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
    
    // ← Neue computed property für UI-Feedback
    var downloadedBooksCount: Int {
        books.filter { downloadManager.isBookDownloaded($0.id) }.count
    }
    
    init(api: AudiobookshelfAPI, player: AudioPlayer, downloadManager: DownloadManager, onBookSelected: @escaping () -> Void) {
        self.api = api
        self.player = player
        self.downloadManager = downloadManager
        self.onBookSelected = onBookSelected
        super.init()
        
        // ← Load saved filter state
        loadFilterSettings()
    }
    
    func loadBooksIfNeeded() async {
        if books.isEmpty {
            await loadBooks()
        }
    }
    
    @MainActor
    func loadBooks() async {
        isLoading = true
        resetError()
        
        do {
            let fetchedBooks: [Book]
            
            if let libraryId = UserDefaults.standard.string(forKey: "selected_library_id") {
                let libraries = try await api.fetchLibraries()
                if let selectedLibrary = libraries.first(where: { $0.id == libraryId }) {
                    libraryName = selectedLibrary.name
                    fetchedBooks = try await api.fetchBooks(from: libraryId)
                    print("\(fetchedBooks.count) Bücher aus Bibliothek '\(selectedLibrary.name)' geladen")
                } else {
                    throw AudiobookshelfError.libraryNotFound("Selected library not found")
                }
            } else {
                let libraries = try await api.fetchLibraries()
                if let firstLibrary = libraries.first {
                    libraryName = firstLibrary.name
                    fetchedBooks = try await api.fetchBooks(from: firstLibrary.id)
                    UserDefaults.standard.set(firstLibrary.id, forKey: "selected_library_id")
                    print("\(fetchedBooks.count) Bücher aus Standard-Bibliothek '\(firstLibrary.name)' geladen")
                } else {
                    libraryName = "Keine Bibliothek"
                    fetchedBooks = []
                }
            }
            
            // Update books with animation
            withAnimation(.easeInOut) {
                books = fetchedBooks
            }
            
            // Optional: Preload first 10 covers for better UX
            if !fetchedBooks.isEmpty {
                CoverCacheManager.shared.preloadCovers(
                    for: Array(fetchedBooks.prefix(10)),
                    api: api,
                    downloadManager: downloadManager
                )
            }
            
        } catch {
            handleError(error)
            print("Fehler beim Laden der Bücher: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    func loadAndPlayBook(_ book: Book) async {
        print("Lade Buch: \(book.title)")
        
        do {
            let fetchedBook = try await api.fetchBookDetails(bookId: book.id)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            player.load(book: fetchedBook)
            onBookSelected()
            print("Buch '\(fetchedBook.title)' geladen")
            print("Buch von '\(fetchedBook.author ?? "Unbekannt")'")

        } catch {
            errorMessage = "Konnte '\(book.title)' nicht laden: \(error.localizedDescription)"
            showingErrorAlert = true
            print("Fehler beim Laden der Buchdetails: \(error)")
        }
    }
    
    // MARK: - ← Neue Filter-Methoden
    
    func toggleDownloadFilter() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showDownloadedOnly.toggle()
        }
        saveFilterSettings()
    }
    
    private func loadFilterSettings() {
        showDownloadedOnly = UserDefaults.standard.bool(forKey: "library_show_downloaded_only")
    }
    
    private func saveFilterSettings() {
        UserDefaults.standard.set(showDownloadedOnly, forKey: "library_show_downloaded_only")
    }
    
    func resetFilters() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showDownloadedOnly = false
            searchText = ""
        }
        saveFilterSettings()
    }
}
