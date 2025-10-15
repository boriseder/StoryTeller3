import Foundation

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

enum PlayBookError: LocalizedError {
    case notAvailableOffline(String)
    case fetchFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAvailableOffline(let title):
            return "'\(title)' is not available offline and no internet connection is available."
        case .fetchFailed(let error):
            return "Could not load book: \(error.localizedDescription)"
        }
    }
}

protocol PlayBookUseCaseProtocol {
    func execute(
        book: Book,
        api: AudiobookshelfAPI,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        appState: AppStateManager,
        restoreState: Bool
    ) async throws
}

class PlayBookUseCase: PlayBookUseCaseProtocol {
    
    func execute(
        book: Book,
        api: AudiobookshelfAPI,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        appState: AppStateManager,
        restoreState: Bool = true
    ) async throws {
        
        let fullBook: Book
        do {
            fullBook = try await api.fetchBookDetails(bookId: book.id)
        } catch {
            throw PlayBookError.fetchFailed(error)
        }
        
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
            AppLogger.debug.debug("[PlayBookUseCase] Loaded book: \(fullBook.title) (mode: online)")
            
        case .offline:
            player.load(book: fullBook, isOffline: true, restoreState: restoreState)
            AppLogger.debug.debug("[PlayBookUseCase] Loaded book: \(fullBook.title) (mode: offline)")
            
        case .unavailable:
            throw PlayBookError.notAvailableOffline(book.title)
        }
    }
    
    private func determinePlaybackMode(
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
}
