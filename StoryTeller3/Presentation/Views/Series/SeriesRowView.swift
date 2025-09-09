import SwiftUI

struct SeriesRowView: View {
    let series: Series
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfAPI
    @ObservedObject var downloadManager: DownloadManager
    let onBookSelected: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Series Header
            seriesHeader
            
            // Books Horizontal Scroll
            booksScrollView
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Series Header
    
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
    
    // MARK: - Books Horizontal Scroll
    
    private var booksScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -50) { // Negative spacing für Überlappung
                ForEach(series.books.indices, id: \.self) { index in
                    if let book = api.convertLibraryItemToBook(series.books[index]) {
                        BookCardView.series(
                            book: book,
                            player: player,
                            api: api,
                            downloadManager: downloadManager,
                            onTap: {
                                Task {
                                    await loadAndPlayBook(book)
                                }
                            }
                        )
                        //.zIndex(Double(series.books.count - index)) // Erste Card oben
                        .offset(x: CGFloat(index) * -15) // Zusätzliches Offset
                    }
                }
            }
            .padding(.horizontal, 20) // Mehr Padding für Überlappung
        }
    }

    // MARK: - Helper Methods
        
    /// Lädt und spielt ein Buch ab (Reuse der LibraryView Logik)
    @MainActor
    private func loadAndPlayBook(_ book: Book) async {
        print("Lade Buch aus Serie: \(book.title)")
        
        do {
            let fetchedBook = try await api.fetchBookDetails(bookId: book.id)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            player.load(book: fetchedBook)
            onBookSelected()
            print("Buch '\(fetchedBook.title)' aus Serie geladen")
        } catch {
            print("Fehler beim Laden der Buchdetails aus Serie: \(error)")
            // Hier könntest du optional Error-Handling hinzufügen
        }
    }
}
