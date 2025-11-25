// AudioPlayer+Bookmarks.swift
// Separate Extension File für Bookmark-Funktionalität

import Foundation

extension AudioPlayer {
    
    /// Jump to a specific bookmark (handles chapter switching if needed)
    func jumpToBookmark(_ bookmark: Bookmark) {
        guard let book = book else {
            AppLogger.general.debug("[AudioPlayer] Cannot jump to bookmark - no book loaded")
            return
        }
        
        let targetChapter = bookmark.chapterIndex(for: book)
        
        AppLogger.general.debug("[AudioPlayer] Jumping to bookmark '\(bookmark.title)' at \(bookmark.formattedTime)")
        
        if targetChapter != currentChapterIndex {
            // Different chapter - need to load it first
            AppLogger.general.debug("[AudioPlayer] Switching to chapter \(targetChapter)")
            currentChapterIndex = targetChapter
            //targetSeekTime = bookmark.time
            loadChapter(shouldResumePlayback: true)
        } else {
            // Same chapter - just seek
            AppLogger.general.debug("[AudioPlayer] Seeking to \(bookmark.time)s in current chapter")
            seek(to: bookmark.time)
        }
    }
    
    /// Get bookmarks for current book
    @MainActor
    func getCurrentBookBookmarks() -> [Bookmark] {
        guard let book = book else { return [] }
        return BookmarkRepository.shared.getBookmarks(for: book.id)
    }
    
    /// Check if there's a bookmark near current time (within tolerance seconds)
    @MainActor
    func checkForNearbyBookmark(tolerance: Double = 5.0) -> Bookmark? {
        guard let book = book else { return nil }
        
        let bookmarks = BookmarkRepository.shared.getBookmarks(for: book.id)
        return bookmarks.first { abs($0.time - currentTime) < tolerance }
    }
    
    /// Get count of bookmarks for current book
    @MainActor
    func getCurrentBookBookmarkCount() -> Int {
        guard let book = book else { return 0 }
        return BookmarkRepository.shared.getBookmarks(for: book.id).count
    }
}

// Usage Examples:
//
// 1. Jump to bookmark:
//    player.jumpToBookmark(bookmark)
//
// 2. Get bookmarks for current book:
//    let bookmarks = await player.getCurrentBookBookmarks()
//
// 3. Check if near a bookmark:
//    if let nearbyBookmark = await player.checkForNearbyBookmark() {
//        print("Near bookmark: \(nearbyBookmark.title)")
//    }
//
// 4. Get bookmark count:
//    let count = await player.getCurrentBookBookmarkCount()
