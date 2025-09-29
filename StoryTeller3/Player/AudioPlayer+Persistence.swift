import SwiftUI

// MARK: - AudioPlayer Persistence Extension
extension AudioPlayer {
    
    // MARK: - Setup Persistence
    func setupPersistence() {
        // Listen for auto-save notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutoSave),
            name: .playbackAutoSave,
            object: nil
        )
        
        // Save when app goes to background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func handleAutoSave() {
        saveCurrentPlaybackState()
    }
    
    @objc private func handleAppBackground() {
        saveCurrentPlaybackState()
    }
    
    // MARK: - Load Previous State
    func loadPreviousPlaybackState(for book: Book) {
        guard let savedState = PlaybackPersistenceManager.shared.loadPlaybackState(for: book.id) else {
            AppLogger.debug.debug("[AudioPlayer] No saved state found for book: \(book.title)")
            return
        }
        
        AppLogger.debug.debug("[AudioPlayer] Restoring playback state: Chapter \(savedState.chapterIndex), Time: \(savedState.currentTime)s")
        
        // Restore chapter
        currentChapterIndex = min(savedState.chapterIndex, book.chapters.count - 1)
        
        // Restore time after player is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Only restore time if we haven't started playing yet
            if self.currentTime < 1.0 {
                self.seek(to: savedState.currentTime)
                AppLogger.debug.debug("[AudioPlayer] Restored playback position: \(savedState.currentTime)s")
            }
        }
    }
    
    // MARK: - Save Current State
    func saveCurrentPlaybackState() {
        guard let book = book else { return }
        
        let state = PlaybackState(
            bookId: book.id,
            chapterIndex: currentChapterIndex,
            currentTime: currentTime,
            duration: duration,
            lastPlayed: Date(),
            isFinished: isBookFinished()
        )
        
        PlaybackPersistenceManager.shared.savePlaybackState(state)
    }
    
    private func isBookFinished() -> Bool {
        guard let book = book else { return false }
        
        // Consider finished if on last chapter and near the end
        let isLastChapter = currentChapterIndex >= book.chapters.count - 1
        let nearEnd = duration > 0 && (currentTime / duration) > 0.95
        
        return isLastChapter && nearEnd
    }
    
    // MARK: - Modified load method with state restoration
    func loadWithStateRestoration(book: Book, isOffline: Bool = false) {
        self.book = book
        // Note: isOfflineMode is private, so we need to modify the load method instead
        
        // Load saved state first
        loadPreviousPlaybackState(for: book)
        
        // Then load using standard method which handles offline mode
        self.load(book: book, isOffline: isOffline)
    }
}

// MARK: - Enhanced Book Loading in ViewModels
extension LibraryViewModel {
    
    @MainActor
    func loadAndPlayBookWithStateRestoration(_ book: Book) async {
        AppLogger.debug.debug("Loading book with state restoration: \(book.title)")
        
        do {
            let fetchedBook = try await api.fetchBookDetails(bookId: book.id)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            
            // Check if book is downloaded for offline playback
            let isOffline = downloadManager.isBookDownloaded(fetchedBook.id)
            
            // Use new method with state restoration
            player.loadWithStateRestoration(book: fetchedBook, isOffline: isOffline)
            
            onBookSelected()
            AppLogger.debug.debug("Book '\(fetchedBook.title)' loaded with restored state")
        } catch {
            errorMessage = "Could not load '\(book.title)': \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.debug.debug("Error loading book details: \(error)")
        }
    }
}

