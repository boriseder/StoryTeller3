import SwiftUI

// MARK: - Base ViewModel
class BaseViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingErrorAlert = false
    
    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        isLoading = false
        showingErrorAlert = true
    }
    
    func resetError() {
        errorMessage = nil
        showingErrorAlert = false
    }
    
    // MARK: - Common Playback Method
    
    /// Load book details and start playback
    /// This method consolidates all loadAndPlayBook implementations across ViewModels
    /// - Parameters:
    ///   - book: Book to play (can be partial data, will fetch full details)
    ///   - api: API client for fetching book details
    ///   - player: Audio player instance
    ///   - downloadManager: Download manager for offline detection
    ///   - restoreState: Whether to restore previous playback position (default: true)
    ///   - onSuccess: Callback executed after successful playback start
    @MainActor
    func loadAndPlayBook(
        _ book: Book,
        api: AudiobookshelfAPI,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        restoreState: Bool = true,
        onSuccess: @escaping () -> Void
    ) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch complete book details
            let fullBook = try await api.fetchBookDetails(bookId: book.id)
            
            // Configure player with API credentials
            player.configure(
                baseURL: api.baseURLString,
                authToken: api.authToken,
                downloadManager: downloadManager
            )
            
            // Determine if book is available offline
            let isOffline = downloadManager.isBookDownloaded(fullBook.id)
            
            // Load book into player
            player.load(book: fullBook, isOffline: isOffline, restoreState: restoreState)
            
            // Execute success callback
            onSuccess()
            
            AppLogger.debug.debug("[BaseViewModel] Loaded book: \(fullBook.title)")
            
        } catch {
            errorMessage = "Could not load '\(book.title)': \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.debug.debug("[BaseViewModel] Failed to load book: \(error)")
        }
        
        isLoading = false
    }
}
