import SwiftUI

struct DownloadsView: View {
    @StateObject private var viewModel: DownloadsViewModel
    
    init(downloadManager: DownloadManager, player: AudioPlayer, api: AudiobookshelfAPI?, onBookSelected: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: DownloadsViewModel(
            downloadManager: downloadManager,
            player: player,
            onBookSelected: onBookSelected
        ))
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 132, maximum: 160), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            DynamicMusicBackground()
            Group {
                if viewModel.downloadedBooks.isEmpty {
                    NoDownloadsView()
                } else {
                    contentView
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .alert("Delete book", isPresented: $viewModel.showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    viewModel.cancelDelete()
                }
                Button("Delete", role: .destructive) {
                    viewModel.confirmDeleteBook()
                }
            } message: {
                if let book = viewModel.bookToDelete {
                    Text("Are you sure? '\(book.title)' will be delete.")
                }
            }
        }
    }
       
    private var contentView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.downloadedBooks) { book in
                    BookCardView(
                        book: book,
                        player: viewModel.player,
                        api: nil, // API ist optional für Downloads
                        downloadManager: viewModel.downloadManager,
                        style: .library,
                        onTap: {
                            viewModel.playBook(book)
                        }
                    )

                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }
}
