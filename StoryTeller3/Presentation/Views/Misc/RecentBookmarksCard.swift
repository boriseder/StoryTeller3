import SwiftUI

// MARK: - Recent Bookmarks Card (für HomeView)
struct RecentBookmarksCard: View {
    @StateObject private var repository = BookmarkRepository.shared
    @EnvironmentObject var dependencies: DependencyContainer
    @EnvironmentObject var theme: ThemeManager
    @ObservedObject private var library = DependencyContainer.shared.libraryViewModel
    @State private var showingAllBookmarks = false
    
    private var player: AudioPlayer { dependencies.player }
    
    private var recentBookmarks: [BookmarkWithBook] {
        let recent = repository.getRecentBookmarks(limit: 5)
        
        // Debug: Zeige Library Status
        AppLogger.general.debug("[RecentBookmarks] 📊 Status:")
        AppLogger.general.debug("  Library books: \(dependencies.libraryViewModel.books.count)")
        AppLogger.general.debug("  Downloaded books: \(dependencies.downloadManager.downloadedBooks.count)")
        AppLogger.general.debug("  Recent bookmarks: \(recent.count)")
        
        return recent.compactMap { bookmark in
            // Debug: Zeige Bookmark Details
            AppLogger.general.debug("[RecentBookmarks] Processing bookmark '\(bookmark.title)' for book: \(bookmark.libraryItemId)")
            
            // Zuerst in Library suchen
            if let book = library.books.first(where: { $0.id == bookmark.libraryItemId }) {
                AppLogger.general.debug("[RecentBookmarks] ✅ Found in library: \(book.title)")
                return BookmarkWithBook(bookmark: bookmark, book: book)
            }
            
            // Dann in Downloads suchen
            if let book = dependencies.downloadManager.downloadedBooks.first(where: { $0.id == bookmark.libraryItemId }) {
                AppLogger.general.debug("[RecentBookmarks] ✅ Found in downloads: \(book.title)")
                return BookmarkWithBook(bookmark: bookmark, book: book)
            }
            
            // Book nicht gefunden - zeige Bookmark trotzdem an
            AppLogger.general.debug("[RecentBookmarks] ❌ Book not found for: \(bookmark.libraryItemId)")
            
            // Debug: Zeige erste paar Library Book IDs zum Vergleich
            if dependencies.libraryViewModel.books.count > 0 {
                let firstThreeIds = dependencies.libraryViewModel.books.prefix(3).map { $0.id }.joined(separator: ", ")
                AppLogger.general.debug("[RecentBookmarks]    Library sample IDs: \(firstThreeIds)")
            }
            
            return BookmarkWithBook(bookmark: bookmark, book: nil)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "bookmark")
                    .font(DSText.itemTitle)
                    .foregroundColor(theme.textColor)
                
                Text("Recent Bookmarks")
                    .font(DSText.itemTitle)
                    .foregroundColor(theme.textColor)
                
                Spacer()
                
                if !recentBookmarks.isEmpty {
                    Button {
                        showingAllBookmarks = true
                    } label: {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.horizontal)
            
            if recentBookmarks.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DSLayout.elementGap) {
                        ForEach(recentBookmarks) { item in
                            BookmarkMiniCard(
                                item: item,
                                onTap: { jumpToBookmark(item) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
        .sheet(isPresented: $showingAllBookmarks) {
            NavigationStack {
                QuickBookmarkDebugView()
                    .environmentObject(dependencies)

                //AllBookmarksView()
                //    .environmentObject(dependencies)
            }
        }
        .task {
            if dependencies.libraryViewModel.books.isEmpty {
                AppLogger.general.debug("➡️ Loading books from DebugView")
                await dependencies.libraryViewModel.loadBooks()
                AppLogger.general.debug("➡️ Loaded books: \(dependencies.libraryViewModel.books.count)")
            }
        }

    }
    
    private var emptyState: some View {
        VStack(spacing: DSLayout.elementGap) {
            Image(systemName: "bookmark")
                .font(.largeTitle)
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No bookmarks yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func jumpToBookmark(_ item: BookmarkWithBook) {
        guard let book = item.book else {
            AppLogger.general.debug("[RecentBookmarks] Cannot jump - book not found")
            return
        }
        
        Task {
            // Load book if not currently playing
            if player.book?.id != book.id {
                await player.load(book: book, isOffline: false, restoreState: false, autoPlay: false)
            }
            
            // Jump to bookmark - the method handles chapter loading and seeking
            await MainActor.run {
                player.jumpToBookmark(item.bookmark)
            }
        }
    }
}

// MARK: - Bookmark Mini Card (für horizontale Liste)
struct BookmarkMiniCard: View {
    let item: BookmarkWithBook
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DSLayout.elementGap) {
                // Book Cover
                if let book = item.book {
                    BookCoverView.square(
                        book: book,
                        size: 100,
                        api: DependencyContainer.shared.apiClient,
                        downloadManager: DependencyContainer.shared.downloadManager,
                        showProgress: false
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    placeholderCover
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Bookmark Title
                    Text(item.bookmark.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .frame(height: 30, alignment: .top)
                    
                    // Book Title
                    if let book = item.book {
                        Text(book.title)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Unknown Book")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .italic()
                    }
                    
                    // Time
                    Label(item.bookmark.formattedTime, systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120)
            .padding(10)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(item.book == nil)
        .opacity(item.book == nil ? 0.6 : 1.0)
    }
    
    private var placeholderCover: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.3),
                            Color.orange.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .cornerRadius(8)
            
            VStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .font(.title)
                    .foregroundColor(.white)
                Text("Not Loaded")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

// MARK: - Bookmark Statistics Card
struct BookmarkStatsCard: View {
    @StateObject private var repository = BookmarkRepository.shared
    
    var body: some View {
        HStack(spacing: DSLayout.contentGap) {
            // Total Bookmarks
            StatItemView(
                icon: "bookmark.fill",
                value: "\(repository.totalBookmarkCount)",
                label: "Bookmarks",
                color: .blue
            )
            
            Divider()
                .frame(height: 40)
            
            // Books with Bookmarks
            StatItemView(
                icon: "books.vertical.fill",
                value: "\(repository.booksWithBookmarks)",
                label: "Books",
                color: .green
            )
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Stat Item View (umbenannt um Konflikt zu vermeiden)
struct StatItemView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DSLayout.elementGap) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Bookmark Quick Access Button (für Toolbar)
struct BookmarkQuickAccessButton: View {
    @StateObject private var repository = BookmarkRepository.shared
    @State private var showingAllBookmarks = false
    
    var body: some View {
        Button {
            showingAllBookmarks = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bookmark")
                
                if repository.totalBookmarkCount > 0 {
                    Text("\(repository.totalBookmarkCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }
        }
        .sheet(isPresented: $showingAllBookmarks) {
            NavigationStack {
                AllBookmarksView()
            }
        }
    }
}
