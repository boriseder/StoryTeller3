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
    
    @Environment(\.dismiss) private var dismiss
    @State private var seriesBooks: [Book] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Compact Header
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
                        booksScrollView
                    }
                }
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
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Lade Serie...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Fehler beim Laden")
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
                Text("Erneut versuchen")
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
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Keine Bücher gefunden")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Diese Serie enthält keine Bücher")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
            
            // ✅ REUSE: HorizontalBookScrollView (identisch mit SeriesView!)
            HorizontalBookScrollView(
                books: seriesBooks,
                player: player,
                api: api,
                downloadManager: downloadManager,
                cardStyle: .series, // Gleicher Style wie in SeriesView
                onBookSelected: { book in
                    Task {
                        await loadAndPlayBook(book)
                    }
                }
            )
        }
    }
    
    // MARK: - Data Loading
    @MainActor
    private func loadSeriesBooks() async {
        guard let seriesId = seriesBook.collapsedSeries?.id,
              let libraryId = UserDefaults.standard.string(forKey: "selected_library_id") else {
            errorMessage = "Serie oder Bibliothek nicht gefunden"
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
            
            // Preload covers für bessere Performance (nur erste 6)
            if !books.isEmpty {
                CoverCacheManager.shared.preloadCovers(
                    for: Array(books.prefix(6)),
                    api: api,
                    downloadManager: downloadManager
                )
            }
            
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
            AppLogger.debug.debug("Fehler beim Laden der Serie: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    private func loadAndPlayBook(_ book: Book) async {
        AppLogger.debug.debug("Lade Buch aus Quick Access: \(book.title)")
        
        do {
            let fetchedBook = try await api.fetchBookDetails(bookId: book.id)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            player.load(book: fetchedBook)
            
            // Close sheet and show player
            dismiss()
            onBookSelected()
            
            AppLogger.debug.debug("Buch '\(fetchedBook.title)' aus Serie geladen")
        } catch {
            errorMessage = "Konnte '\(book.title)' nicht laden: \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.debug.debug("Fehler beim Laden der Buchdetails: \(error)")
        }
    }
}
