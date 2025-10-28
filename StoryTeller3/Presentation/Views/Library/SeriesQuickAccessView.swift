import SwiftUI

struct SeriesQuickAccessView: View {
    @StateObject private var viewModel: SeriesQuickAccessViewModel
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject var appState: AppStateManager
    @Environment(\.dismiss) private var dismiss
    
    // ✅ Infrastructure stored at View level for UI components
    private let player: AudioPlayer
    private let api: AudiobookshelfClient
    private let downloadManager: DownloadManager
    
    init(viewModel: SeriesQuickAccessViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let error = viewModel.errorMessage {
                ErrorView(error: error)
            } else if viewModel.seriesBooks.isEmpty {
                EmptyStateView()
            } else {
                contentView
            }
        }
        .onAppear {
            viewModel.onDismiss = { dismiss() }
        }
    }
 
    private var contentView: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                await viewModel.loadSeriesBooks()
            }
            .alert("Fehler", isPresented: $viewModel.showingErrorAlert) {
                Button("OK") { }
                Button("Erneut versuchen") {
                    Task { await viewModel.loadSeriesBooks() }
                }
            } message: {
                Text(viewModel.errorMessage ?? "Unbekannter Fehler")
            }
        }
    }
    
    private var seriesHeaderView: some View {
        HStack(spacing: 16) {
            // ✅ UI component gets infrastructure for rendering
            BookCoverView.square(
                book: viewModel.seriesBook,
                size: 64,
                api: api,
                downloadManager: downloadManager
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.seriesBook.displayTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                if let author = viewModel.seriesBook.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if !viewModel.seriesBooks.isEmpty {
                    HStack(spacing: 12) {
                        Text("\(viewModel.seriesBooks.count) Books")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if viewModel.downloadedCount > 0 {
                            Text("• \(viewModel.downloadedCount) downloaded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
    }

    private var booksScrollView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Books of the series")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            // ✅ UI component gets infrastructure for rendering
            HorizontalBookScrollView(
                books: viewModel.seriesBooks,
                player: player,
                api: api,
                downloadManager: downloadManager,
                cardStyle: .series,
                onBookSelected: { book in
                    Task {
                        await viewModel.playBook(book, appState: appState)
                    }
                }
            )
        }
    }
}
