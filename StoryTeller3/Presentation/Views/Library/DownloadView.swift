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
        NavigationStack {
            Group {
                if viewModel.downloadedBooks.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .alert("Buch löschen", isPresented: $viewModel.showingDeleteConfirmation) {
                Button("Abbrechen", role: .cancel) {
                    viewModel.cancelDelete()
                }
                Button("Löschen", role: .destructive) {
                    viewModel.confirmDeleteBook()
                }
            } message: {
                if let book = viewModel.bookToDelete {
                    Text("Möchten Sie '\(book.title)' wirklich von diesem Gerät löschen?")
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
            
            VStack(spacing: 8) {
                Text("Keine Downloads")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Laden Sie Bücher aus der Bibliothek herunter, um sie offline zu hören")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
