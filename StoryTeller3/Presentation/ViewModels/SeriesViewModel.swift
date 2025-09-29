//
//  SeriesViewModel.swift
//  StoryTeller3
//
//  Created by Boris Eder on 09.09.25.
//

import SwiftUI

class SeriesViewModel: BaseViewModel {
    @Published var series: [Series] = []
    @Published var searchText = ""
    @Published var selectedSortOption: SeriesSortOption = .name
    @Published var libraryName: String = "Serien"
    
    let api: AudiobookshelfAPI
    let player: AudioPlayer
    let downloadManager: DownloadManager
    private let onBookSelected: () -> Void
    
    var filteredAndSortedSeries: [Series] {
        let filtered = searchText.isEmpty ? series : series.filter { series in
            series.name.localizedCaseInsensitiveContains(searchText) ||
            (series.author?.localizedCaseInsensitiveContains(searchText) ?? false)
        }

        return filtered.sorted { series1, series2 in
            switch selectedSortOption {
            case .name:
                return series1.name.localizedCompare(series2.name) == .orderedAscending
            case .recent:
                return series1.addedAt > series2.addedAt
            case .bookCount:
                return series1.bookCount > series2.bookCount
            case .duration:
                return series1.totalDuration > series2.totalDuration
            }
        }
    }
    
    init(api: AudiobookshelfAPI, player: AudioPlayer, downloadManager: DownloadManager, onBookSelected: @escaping () -> Void) {
        self.api = api
        self.player = player
        self.downloadManager = downloadManager
        self.onBookSelected = onBookSelected
        super.init()
    }
    
    func loadSeriesIfNeeded() async {
        if series.isEmpty {
            await loadSeries()
        }
    }
    
    @MainActor
    func loadSeries() async {
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
                libraryName = "Serien"
                series = []
                isLoading = false
                return
            }

            libraryName = "\(selectedLibrary.name) - Serien"
            let fetchedSeries = try await api.fetchSeries(from: selectedLibrary.id)
            
            // Update series with animation
            withAnimation(.easeInOut) {
                series = fetchedSeries
            }
            
        } catch {
            handleError(error)
            AppLogger.debug.debug("Fehler beim Laden der Serien: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    func loadAndPlayBook(_ book: Book, restoreState: Bool = true) async {
        AppLogger.debug.debug("Loading book from series: \(book.title), restoreState: \(restoreState)")
        
        do {
            let fetchedBook = try await api.fetchBookDetails(bookId: book.id)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            
            let isOffline = downloadManager.isBookDownloaded(fetchedBook.id)
            player.load(book: fetchedBook, isOffline: isOffline, restoreState: restoreState)
            
            onBookSelected()
            AppLogger.debug.debug("Book '\(fetchedBook.title)' loaded from series")
        } catch {
            errorMessage = "Could not load '\(book.title)': \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.debug.debug("Error loading book details from series: \(error)")
        }
    }

    func convertLibraryItemToBook(_ item: LibraryItem) -> Book? {
        return api.convertLibraryItemToBook(item)
    }

}

