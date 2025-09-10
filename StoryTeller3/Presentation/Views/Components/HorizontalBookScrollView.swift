import SwiftUI

// MARK: - Reusable HorizontalBookScrollView Component

struct HorizontalBookScrollView: View {
    let books: [Book]
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfAPI
    @ObservedObject var downloadManager: DownloadManager
    let onBookSelected: (Book) -> Void
    let cardStyle: BookCardStyle
    
    init(
        books: [Book],
        player: AudioPlayer,
        api: AudiobookshelfAPI,
        downloadManager: DownloadManager,
        cardStyle: BookCardStyle = .series,
        onBookSelected: @escaping (Book) -> Void
    ) {
        self.books = books
        self.player = player
        self.api = api
        self.downloadManager = downloadManager
        self.cardStyle = cardStyle
        self.onBookSelected = onBookSelected
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(books) { book in
                    BookCardView(
                        book: book,
                        player: player,
                        api: api,
                        downloadManager: downloadManager,
                        style: cardStyle,
                        onTap: {
                            onBookSelected(book)
                        }
                    )
                }
            }
           // .padding(.horizontal, 10)
        }
    }
}
