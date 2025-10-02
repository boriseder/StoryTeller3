import SwiftUI

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
    
    // MARK: - Playback Mode
    
    enum PlaybackMode: CustomStringConvertible {
        case online
        case offline
        case unavailable
        
        var description: String {
            switch self {
            case .online: return "online"
            case .offline: return "offline"
            case .unavailable: return "unavailable"
            }
        }
    }
    
    func determinePlaybackMode(
        book: Book,
        downloadManager: DownloadManager,
        appState: AppStateManager
    ) -> PlaybackMode {
        let isDownloaded = downloadManager.isBookDownloaded(book.id)
        let hasConnection = appState.isDeviceOnline && appState.isServerReachable
        
        if isDownloaded {
            return .offline
        }
        
        if hasConnection {
            return .online
        }
        
        return .unavailable
    }
    
    // MARK: - Common Playback Method
    
    @MainActor
    func loadAndPlayBook(
        _ book: Book,
        api: AudiobookshelfAPI,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        appState: AppStateManager,
        restoreState: Bool = true,
        onSuccess: @escaping () -> Void
    ) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fullBook = try await api.fetchBookDetails(bookId: book.id)
            
            player.configure(
                baseURL: api.baseURLString,
                authToken: api.authToken,
                downloadManager: downloadManager
            )
            
            let playbackMode = determinePlaybackMode(
                book: fullBook,
                downloadManager: downloadManager,
                appState: appState
            )
            
            switch playbackMode {
            case .online:
                player.load(book: fullBook, isOffline: false, restoreState: restoreState)
                onSuccess()
                
            case .offline:
                player.load(book: fullBook, isOffline: true, restoreState: restoreState)
                onSuccess()
                
            case .unavailable:
                errorMessage = "'\(book.title)' is not available offline and no internet connection is available."
                showingErrorAlert = true
            }
            
            AppLogger.debug.debug("[BaseViewModel] Loaded book: \(fullBook.title) (mode: \(playbackMode))")
            
        } catch {
            errorMessage = "Could not load '\(book.title)': \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.debug.debug("[BaseViewModel] Failed to load book: \(error)")
        }
        
        isLoading = false
    }
}
