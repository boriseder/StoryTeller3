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
            print("Fehler beim Laden der Serien: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    func loadAndPlayBook(_ book: Book) async {
        print("Lade Buch aus Serie: \(book.title)")
        
        do {
            let fetchedBook = try await api.fetchBookDetails(bookId: book.id)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            player.load(book: fetchedBook)
            onBookSelected()
            print("Buch '\(fetchedBook.title)' aus Serie geladen")
        } catch {
            errorMessage = "Konnte '\(book.title)' nicht laden: \(error.localizedDescription)"
            showingErrorAlert = true
            print("Fehler beim Laden der Buchdetails aus Serie: \(error)")
        }
    }
    
    /// Konvertiert LibraryItem zu Book (Helper-Methode)
    func convertLibraryItemToBook(_ item: LibraryItem) -> Book? {
        let chapters: [Chapter] = {
            if let mediaChapters = item.media.chapters, !mediaChapters.isEmpty {
                return mediaChapters.map { chapter in
                    Chapter(
                        id: chapter.id,
                        title: chapter.title,
                        start: chapter.start,
                        end: chapter.end,
                        libraryItemId: item.id,
                        episodeId: chapter.episodeId
                    )
                }
            } else if let tracks = item.media.tracks, !tracks.isEmpty {
                return tracks.enumerated().map { index, track in
                    Chapter(
                        id: "\(index)",
                        title: track.title ?? "Kapitel \(index + 1)",
                        start: track.startOffset,
                        end: track.startOffset + track.duration,
                        libraryItemId: item.id
                    )
                }
            } else {
                return [Chapter(
                    id: "0",
                    title: item.media.metadata.title,
                    start: 0,
                    end: item.media.duration ?? 3600,
                    libraryItemId: item.id
                )]
            }
        }()
        
        return Book(
            id: item.id,
            title: item.media.metadata.title,
            author: item.media.metadata.author,
            chapters: chapters,
            coverPath: item.coverPath
        )
    }
}

