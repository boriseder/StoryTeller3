import SwiftUI
// MARK: - Continue Reading Section
struct ContinueReadingSection: View {
    @StateObject private var viewModel: ContinueReadingViewModel
    
    let player: AudioPlayer
    let api: AudiobookshelfAPI
    let downloadManager: DownloadManager
    let onBookSelected: () -> Void
    
    init(
        viewModel: ContinueReadingViewModel,
        player: AudioPlayer,
        api: AudiobookshelfAPI,
        downloadManager: DownloadManager,
        onBookSelected: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.player = player
        self.api = api
        self.downloadManager = downloadManager
        self.onBookSelected = onBookSelected
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader
            
            if viewModel.recentBooks.isEmpty {
                emptyStateView
            } else {
                recentBooksScrollView
            }
        }
        .onAppear {
            viewModel.loadRecentBooks()
        }
        .refreshable {
            await viewModel.sync()
        }
    }
    
    private var sectionHeader: some View {
        HStack {
            Label("Continue Reading", systemImage: "book.closed.fill")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            syncStatusIndicator
        }
    }
    
    private var syncStatusIndicator: some View {
        Group {
            switch viewModel.syncStatus {
            case .idle:
                EmptyView()
            case .syncing:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Syncing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            case .success(let date):
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("Synced \(timeAgo(date))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            case .failed(_):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Sync failed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.circle")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("No recent books")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Start listening to see your progress here")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
    
    private var recentBooksScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.recentBooks, id: \.bookId) { state in
                    ContinueReadingCard(
                        state: state,
                        player: player,
                        api: api,
                        downloadManager: downloadManager,
                        viewModel: viewModel,
                        onTap: {
                            Task {
                                await resumeBook(state)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func resumeBook(_ state: PlaybackState) async {
        do {
            let book = try await api.fetchBookDetails(bookId: state.bookId)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            
            let isOffline = downloadManager.isBookDownloaded(book.id)
            player.load(book: book, isOffline: isOffline, restoreState: true)
            
            onBookSelected()
        } catch {
            AppLogger.general.debug("Failed to resume book: \(error)")
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            return "\(Int(interval/60))m ago"
        } else {
            return "\(Int(interval/3600))h ago"
        }
    }
}

// MARK: - Continue Reading Card
struct ContinueReadingCard: View {
    let state: PlaybackState
    let player: AudioPlayer
    let api: AudiobookshelfAPI
    let downloadManager: DownloadManager
    let viewModel: ContinueReadingViewModel
    let onTap: () -> Void
    
    @State private var book: Book?
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottom) {
                    if let book = book {
                        BookCoverView.square(
                            book: book,
                            size: 120,
                            api: api,
                            downloadManager: downloadManager
                        )
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .overlay(
                                ProgressView()
                            )
                    }
                    
                    VStack(spacing: 0) {
                        Spacer()
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(height: 4)
                                
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(width: geometry.size.width * state.progress, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    if let book = book {
                        Text(book.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        if let author = book.author {
                            Text(author)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("Syncing...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(viewModel.getProgressText(for: state))
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        
                        Spacer()
                        
                        Text(viewModel.getTimeAgoText(for: state))
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .task {
            await loadBookInfo()
        }
    }
    
    private func loadBookInfo() async {
        do {
            let loadedBook = try await api.fetchBookDetails(bookId: state.bookId)
            await MainActor.run {
                self.book = loadedBook
            }
        } catch {
            AppLogger.general.debug("Failed to load book info for continue reading: \(error)")
        }
    }
}
