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
            VStack(spacing: 0) {
                // Series Header
                seriesHeaderView
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                
                Divider()
                
                // Content
                Group {
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if seriesBooks.isEmpty {
                        emptyStateView
                    } else {
                        booksGridView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task {
                await loadSeriesBooks()
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
                Button("Retry") {
                    Task { await loadSeriesBooks() }
                }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }
    
    // MARK: - Series Header
    private var seriesHeaderView: some View {
        HStack(spacing: 16) {
            // Series Cover
            if let firstBook = seriesBooks.first {
                BookCoverView.square(
                    book: firstBook,
                    size: 80,
                    api: api,
                    downloadManager: downloadManager
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else if let firstLibraryItem = series.books.first {
                // Fallback: convert LibraryItem to Book
                let fallbackBook = Book(
                    id: firstLibraryItem.id,
                    title: firstLibraryItem.media.metadata.title,
                    author: firstLibraryItem.media.metadata.author,
                    chapters: [],
                    coverPath: firstLibraryItem.coverPath,
                    collapsedSeries: nil
                )
                
                BookCoverView.square(
                    book: fallbackBook,
                    size: 80,
                    api: api,
                    downloadManager: downloadManager
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
            }
            
            // Series Info
            VStack(alignment: .leading, spacing: 6) {
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14))
                        Text("Close")
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(series.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                if let author = series.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Series Stats
                if !seriesBooks.isEmpty {
                    HStack(spacing: 12) {
                        Text("\(seriesBooks.count) books")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let downloadedCount = seriesBooks.filter { downloadManager.isBookDownloaded($0.id) }.count
                        if downloadedCount > 0 {
                            Text("• \(downloadedCount) downloaded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("• \(series.formattedDuration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Content Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading series...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Error loading series")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                Task { await loadSeriesBooks() }
            }) {
                Text("Retry")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No books found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("This series contains no books")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var booksGridView: some View {
        let columns = [
            GridItem(.adaptive(minimum: 120, maximum: 140), spacing: 12)
        ]
        
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(seriesBooks) { book in
                    let viewModel = BookCardStateViewModel(
                        book: book,
                        player: player,
                        downloadManager: downloadManager
                    )
                    
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
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
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
