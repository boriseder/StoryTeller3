import SwiftUI

struct SeriesSectionView: View {
    let series: Series
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfAPI
    @ObservedObject var downloadManager: DownloadManager
    let onBookSelected: () -> Void
    
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
                        await loadAndPlayBook(book)
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
    private func loadAndPlayBook(_ book: Book) async {
        AppLogger.debug.debug("Loading book from series section: \(book.title)")
        
        do {
            let fetchedBook = try await api.fetchBookDetails(bookId: book.id)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            
            let isOffline = downloadManager.isBookDownloaded(fetchedBook.id)
            player.load(book: fetchedBook, isOffline: isOffline, restoreState: true)
            
            onBookSelected()
            AppLogger.debug.debug("Book '\(fetchedBook.title)' loaded from series section")
        } catch {
            AppLogger.debug.debug("Error loading book details from series: \(error)")
        }
    }}
