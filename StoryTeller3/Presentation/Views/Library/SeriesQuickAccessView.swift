//
//  SeriesQuickAccessView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 10.09.25.
//


import SwiftUI

struct SeriesQuickAccessView: View {
    let seriesBook: Book
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfAPI
    @ObservedObject var downloadManager: DownloadManager
    let onBookSelected: () -> Void
    
    // Zugriff auf das EnvironmentObject
    @EnvironmentObject var viewModel: LibraryViewModel

    
    @Environment(\.dismiss) private var dismiss
    @State private var seriesBooks: [Book] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    var body: some View {
        Group {
            switch viewModel.uiState {
            case .loading:
                LoadingView()
            case .error(let message):
                ErrorView(error: message)
            case .empty:
                EmptyStateView()
            case .noDownloads:
                NoDownloadsView()
            case .noSearchResults:
                NoSearchResultsView()
            case .content:
                contentView
            }
        }
    }
 
    private var contentView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Compact Header
                seriesHeaderView
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                
                Divider()
                
                booksScrollView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                await loadSeriesBooks()
            }
            .alert("Fehler", isPresented: $showingErrorAlert) {
                Button("OK") { }
                Button("Erneut versuchen") {
                    Task { await loadSeriesBooks() }
                }
            } message: {
                Text(errorMessage ?? "Unbekannter Fehler")
            }
        }
    }

    
    // MARK: - Compact Series Header
    private var seriesHeaderView: some View {
        HStack(spacing: 16) {
            // Series Cover (kompakt)
            BookCoverView.square(
                book: seriesBook,
                size: 64,
                api: api,
                downloadManager: downloadManager
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Series Info (kompakt)
            VStack(alignment: .leading, spacing: 4) {
                Text(seriesBook.displayTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                if let author = seriesBook.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Quick Stats
                if !seriesBooks.isEmpty {
                    HStack(spacing: 12) {
                        Text("\(seriesBooks.count) Bücher")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let downloadedCount = seriesBooks.filter { downloadManager.isBookDownloaded($0.id) }.count
                        if downloadedCount > 0 {
                            Text("• \(downloadedCount) heruntergeladen")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .background(.yellow)
    }

    // MARK: - Books Scroll View (REUSE! Gleich wie SeriesView)
    private var booksScrollView: some View {
        VStack(spacing: 0) {
            // Section Header (optional)
            HStack {
                Text("Bücher der Serie")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            // REUSE: HorizontalBookScrollView (identisch mit SeriesView!)
            HorizontalBookScrollView(
                books: seriesBooks,
                player: player,
                api: api,
                downloadManager: downloadManager,
                cardStyle: .series, // Gleicher Style wie in SeriesView
                onBookSelected: { book in
                    Task {
                        await playBook(book)
                    }
                }
            )
        }
    }
    
    // MARK: - Data Loading
    @MainActor
    private func loadSeriesBooks() async {
        guard let seriesId = seriesBook.collapsedSeries?.id,
              let libraryId = LibraryHelpers.getCurrentLibraryId() else {            errorMessage = "Serie oder Bibliothek nicht gefunden"
            showingErrorAlert = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let books = try await api.fetchSeriesSingle(from: libraryId, seriesId: seriesId)
            
            withAnimation(.easeInOut(duration: 0.3)) {
                seriesBooks = books
            }
            
            // Preload covers for better performance
            CoverPreloadHelpers.preloadIfNeeded(
                books: books,
                api: api,
                downloadManager: downloadManager
            )
            
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
            AppLogger.debug.debug("Fehler beim Laden der Serie: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    private func playBook(_ book: Book) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedBook = try await api.fetchBookDetails(bookId: book.id)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            
            let isOffline = downloadManager.isBookDownloaded(fetchedBook.id)
            player.load(book: fetchedBook, isOffline: isOffline, restoreState: true)
            
            dismiss()
            onBookSelected()
            
            AppLogger.debug.debug("[SeriesQuickAccessView] Loaded book: \(fetchedBook.title)")
            
        } catch {
            errorMessage = "Could not load '\(book.title)': \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.debug.debug("[SeriesQuickAccessView] Failed to load book: \(error)")
        }
        
        isLoading = false
    }}
