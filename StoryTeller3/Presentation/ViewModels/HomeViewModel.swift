//
//  HomeViewModel.swift
//  StoryTeller3
//
//  Created by Assistant on 10.09.25
//

import SwiftUI

class HomeViewModel: BaseViewModel {
    @Published var personalizedBooks: [Book] = []
    @Published var libraryName: String = "Personalisiert"
    
    let api: AudiobookshelfAPI
    let player: AudioPlayer
    let downloadManager: DownloadManager
    private let onBookSelected: () -> Void
    
    var downloadedCount: Int {
        personalizedBooks.filter { downloadManager.isBookDownloaded($0.id) }.count
    }
    
    init(api: AudiobookshelfAPI, player: AudioPlayer, downloadManager: DownloadManager, onBookSelected: @escaping () -> Void) {
        self.api = api
        self.player = player
        self.downloadManager = downloadManager
        self.onBookSelected = onBookSelected
        super.init()
    }
    
    func loadPersonalizedBooksIfNeeded() async {
        if personalizedBooks.isEmpty {
            await loadPersonalizedBooks()
        }
    }
    
    @MainActor
    func loadPersonalizedBooks() async {
        isLoading = true
        resetError()
        
        do {
            let libraries = try await api.fetchLibraries()
            let selectedLibrary: Library

            if let savedId = UserDefaults.standard.string(forKey: "selected_library_id"),
               let found = libraries.first(where: { $0.id == savedId }) {
                selectedLibrary = found
            } else if let first = libraries.first {
                selectedLibrary = first
                UserDefaults.standard.set(first.id, forKey: "selected_library_id")
            } else {
                // keine Bibliothek vorhanden
                libraryName = "Personalisiert"
                personalizedBooks = []
                isLoading = false
                return
            }

            libraryName = "\(selectedLibrary.name) - Empfehlungen"
            let fetchedBooks = try await api.fetchPersonalizedBooks(from: selectedLibrary.id)
            
            // Update books with animation
            withAnimation(.easeInOut) {
                personalizedBooks = fetchedBooks
            }
            
            // Preload covers für bessere Performance (nur erste 10)
            if !fetchedBooks.isEmpty {
                CoverCacheManager.shared.preloadCovers(
                    for: Array(fetchedBooks.prefix(10)),
                    api: api,
                    downloadManager: downloadManager
                )
            }
            
        } catch {
            handleError(error)
            AppLogger.debug.debug("Fehler beim Laden der personalisierten Bücher: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    func loadAndPlayBook(_ book: Book) async {
        AppLogger.debug.debug("Lade Buch aus Empfehlungen: \(book.title)")
        
        do {
            let fetchedBook = try await api.fetchBookDetails(bookId: book.id)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            player.load(book: fetchedBook)
            onBookSelected()
            AppLogger.debug.debug("Buch '\(fetchedBook.title)' aus Empfehlungen geladen")
        } catch {
            errorMessage = "Konnte '\(book.title)' nicht laden: \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.debug.debug("Fehler beim Laden der Buchdetails aus Empfehlungen: \(error)")
        }
    }
}

extension HomeViewModel {
    var uiState: HomeUIState {
        if isLoading {
            return .loading
        } else if let error = errorMessage {
            return .error(error)
        } else if personalizedBooks.isEmpty {
            return .empty
        } else {
            return .content
        }
    }
}
