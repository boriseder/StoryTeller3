//
//  BookmarkTimelineView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 24.11.25.
//


import SwiftUI

// MARK: - Bookmark Badge für BookCard
extension BookCardView {
    var bookmarkBadge: some View {
        Group {
            if BookmarkRepository.shared.getBookmarks(for: viewModel.book.id).count > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 10))
                    Text("\(BookmarkRepository.shared.getBookmarks(for: viewModel.book.id).count)")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.orange)
                .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Bookmark Context Menu Extension
extension View {
    func bookmarkContextMenu(for book: Book, currentTime: Double) -> some View {
        self.contextMenu {
            Button {
                // Quick bookmark at current time
                Task {
                    do {
                        try await BookmarkRepository.shared.createBookmark(
                            libraryItemId: book.id,
                            time: currentTime,
                            title: "Bookmark at \(TimeFormatter.formatTime(currentTime))"
                        )
                    } catch {
                        AppLogger.general.debug("[ContextMenu] Bookmark creation failed: \(error)")
                    }
                }
            } label: {
                Label("Add Bookmark Here", systemImage: "bookmark")
            }
            
            if !BookmarkRepository.shared.getBookmarks(for: book.id).isEmpty {
                Button {
                    // Show bookmarks for this book
                } label: {
                    Label("View Bookmarks (\(BookmarkRepository.shared.getBookmarks(for: book.id).count))", 
                          systemImage: "bookmark.fill")
                }
            }
        }
    }
}

// MARK: - Bookmark Search Extensions
extension Bookmark {
    func matches(searchQuery: String) -> Bool {
        let query = searchQuery.lowercased()
        return title.lowercased().contains(query)
    }
}

extension Array where Element == Bookmark {
    func filtered(by query: String) -> [Bookmark] {
        guard !query.isEmpty else { return self }
        return filter { $0.matches(searchQuery: query) }
    }
    
    func sorted(by option: BookmarkSortOption) -> [Bookmark] {
        switch option {
        case .dateNewest:
            return sorted { $0.createdAt > $1.createdAt }
        case .dateOldest:
            return sorted { $0.createdAt < $1.createdAt }
        case .timeInBook:
            return sorted { $0.time < $1.time }
        case .bookTitle:
            return sorted { $0.libraryItemId < $1.libraryItemId }
        }
    }
}

// MARK: - Bookmark Export/Import (Optional - für Backup)
/*
extension BookmarkRepository {
    
    /// Export all bookmarks as JSON
    func exportBookmarks() -> Data? {
        let allBookmarks = bookmarks.values.flatMap { $0 }
        return try? JSONEncoder().encode(allBookmarks)
    }
    
    /// Import bookmarks from JSON
    func importBookmarks(from data: Data) throws {
        let imported = try JSONDecoder().decode([Bookmark].self, from: data)
        
        var grouped: [String: [Bookmark]] = [:]
        for bookmark in imported {
            grouped[bookmark.libraryItemId, default: []].append(bookmark)
        }
        
        for (key, value) in grouped {
            grouped[key] = value.sorted { $0.time < $1.time }
        }
        
        self.bookmarks = grouped
        saveCachedBookmarks()
        
        AppLogger.general.debug("[BookmarkRepo] 📥 Imported \(imported.count) bookmarks")
    }
    
    /// Share bookmarks as file
    func shareBookmarks() -> URL? {
        guard let data = exportBookmarks() else { return nil }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("bookmarks_export.json")
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            AppLogger.general.debug("[BookmarkRepo] Export failed: \(error)")
            return nil
        }
    }
}

 // MARK: - Bookmark Notification (Optional - für "In der Nähe eines Bookmarks")
extension AudioPlayer {
    
    /// Check if we're near a bookmark (within 3 seconds)
    func checkForNearbyBookmark() -> Bookmark? {
        guard let book = book else { return nil }
        
        let bookmarks = BookmarkRepository.shared.getBookmarks(for: book.id)
        return bookmarks.first { abs($0.time - currentTime) < 3.0 }
    }
    
    /// Show notification when near bookmark (can be called in time observer)
    func notifyIfNearBookmark() {
        if let nearbyBookmark = checkForNearbyBookmark() {
            // Show a subtle notification or highlight in UI
            NotificationCenter.default.post(
                name: .nearBookmark,
                object: nil,
                userInfo: ["bookmark": nearbyBookmark]
            )
        }
    }
}
*/
extension Notification.Name {
    static let nearBookmark = Notification.Name("nearBookmark")
}

// MARK: - Bookmark Timeline View (visualisiert Bookmarks auf Timeline)
/*
struct BookmarkTimelineView: View {
    let book: Book
    let bookmarks: [Bookmark]
    let currentTime: Double
    let onBookmarkTap: (Bookmark) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Timeline Background
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 8)
                
                // Bookmark Markers
                ForEach(bookmarks) { bookmark in
                    let position = (bookmark.time / book.duration) * geometry.size.width
                    
                    Button {
                        onBookmarkTap(bookmark)
                    } label: {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 12, height: 12)
                            .overlay {
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            }
                    }
                    .offset(x: position - 6)
                }
                
                // Current Position
                let currentPosition = (currentTime / book.duration) * geometry.size.width
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 16, height: 16)
                    .offset(x: currentPosition - 8)
            }
        }
        .frame(height: 20)
    }
}
*/
// Usage in Player:
// BookmarkTimelineView(
//     book: player.book,
//     bookmarks: BookmarkRepository.shared.getBookmarks(for: player.book.id),
//     currentTime: player.currentTime,
//     onBookmarkTap: { bookmark in
//         player.jumpToBookmark(bookmark)
//     }
// )
