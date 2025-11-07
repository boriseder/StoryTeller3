//
//  SeriesDetailSheet.swift
//  StoryTeller3
//

import SwiftUI

struct SeriesDetailSheet: View {
    let series: Series
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfClient
    @ObservedObject var downloadManager: DownloadManager
    let onBookSelected: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var seriesBooks: [Book] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DSLayout.contentGap) {
                // Series Header
                seriesHeaderView
                
                Divider()
                
                booksGridView
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                await loadSeriesBooks()
            }
        }
    }
    
    // MARK: - Series Header
    private var seriesHeaderView: some View {
        HStack(alignment: .top) {
            // Series Info
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(series.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Stats
                if !seriesBooks.isEmpty {
                    HStack(spacing: DSLayout.elementGap) {
                        Text("\(seriesBooks.count) books")
                        
                        let downloadedCount = seriesBooks.filter { downloadManager.isBookDownloaded($0.id) }.count
                        if downloadedCount > 0 {
                            Text("• \(downloadedCount) downloaded")
                        }
                        
                        Text("• \(series.formattedDuration)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .layoutPriority(1) // verhindert, dass der Titel zu klein wird
            
            Spacer()
            
            // Dismiss Button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DSLayout.screenPadding)
        .padding(.top, DSLayout.comfortPadding)
    }


    // MARK: - Content Views
    private var booksGridView: some View {
        
        ScrollView {
            LazyVGrid(columns: DSGridColumns.two, spacing: 0) {
                ForEach(seriesBooks) { book in
                    let viewModel = BookCardStateViewModel(book: book)
                    
                    BookCardView(
                        viewModel: viewModel,
                        api: api,
                        onTap: {
                            Task {
                                await playBook(book)
                            }
                        },
                        onDownload: {
                            Task {
                                await downloadManager.downloadBook(book, api: api)
                            }
                        },
                        onDelete: {
                            downloadManager.deleteBook(book.id)
                        },
                        style: .series
                    )
                }
            }
            .padding(.horizontal, DSLayout.contentPadding)
        }
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadSeriesBooks() async {
        guard let libraryId = LibraryHelpers.getCurrentLibraryId() else {            errorMessage = "No library selected"
            showingErrorAlert = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let books = try await api.series.fetchSeriesBooks(libraryId: libraryId, seriesId: series.id)
            
            withAnimation(.easeInOut(duration: 0.3)) {
                seriesBooks = books
            }
            
            // Preload covers for better performance
            // Preload covers for better performance
            CoverPreloadHelpers.preloadIfNeeded(
                books: books,
                api: api,
                downloadManager: downloadManager
            )
            
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
            AppLogger.general.debug("Error loading series books: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    private func playBook(_ book: Book) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedBook = try await api.books.fetchBookDetails(bookId: book.id, retryCount: 3)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            
            let isOffline = downloadManager.isBookDownloaded(fetchedBook.id)
            player.load(book: fetchedBook, isOffline: isOffline, restoreState: true)
            
            dismiss()
            onBookSelected()
            
            AppLogger.general.debug("[SeriesDetailSheet] Loaded book: \(fetchedBook.title)")
            
        } catch {
            errorMessage = "Could not load '\(book.title)': \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.general.debug("[SeriesDetailSheet] Failed to load book: \(error)")
        }
        
        isLoading = false
    }
}
