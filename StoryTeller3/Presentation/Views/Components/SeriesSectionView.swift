import SwiftUI

struct SeriesSectionView: View {
    let series: Series
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfAPI
    @ObservedObject var downloadManager: DownloadManager
    let onBookSelected: () -> Void
    
    @EnvironmentObject var appState: AppStateManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Series Header
            seriesHeader
            
            // Books Horizontal Scroll - ← REUSE!
            HorizontalBookScrollView(
                books: series.books.compactMap { api.convertLibraryItemToBook($0) },
                player: player,
                api: api,
                downloadManager: downloadManager,
                cardStyle: .series,
                onBookSelected: { book in
                    Task {
                        await playBook(book)
                    }
                }
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background  {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            
        }
    }
    
    // MARK: - Series Header (unchanged)
    
    private var seriesHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(series.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let author = series.author {
                        Text(author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Series Stats
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(series.bookCount) Bücher")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(series.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func playBook(_ book: Book) async {
        do {
            let fetchedBook = try await api.fetchBookDetails(bookId: book.id)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            
            let playbackMode = determinePlaybackMode(
                book: fetchedBook,
                downloadManager: downloadManager,
                appState: appState
            )
            
            switch playbackMode {
            case .online:
                player.load(book: fetchedBook, isOffline: false, restoreState: true)
                onBookSelected()
                
            case .offline:
                player.load(book: fetchedBook, isOffline: true, restoreState: true)
                onBookSelected()
                
            case .unavailable:
                AppLogger.debug.debug("[SeriesSectionView] Book not available offline and no connection")
            }
            
            AppLogger.debug.debug("[SeriesSectionView] Loaded book: \(fetchedBook.title)")
        } catch {
            AppLogger.debug.debug("[SeriesSectionView] Failed to load book: \(error)")
        }
    }
    
    private func determinePlaybackMode(
        book: Book,
        downloadManager: DownloadManager,
        appState: AppStateManager
    ) -> BaseViewModel.PlaybackMode {
        let isDownloaded = downloadManager.isBookDownloaded(book.id)
        let hasConnection = appState.isDeviceOnline && appState.isServerReachable
        
        if isDownloaded {
            return .offline
        }
        
        if hasConnection {
            return .online
        }
        
        return .unavailable
    }
}
