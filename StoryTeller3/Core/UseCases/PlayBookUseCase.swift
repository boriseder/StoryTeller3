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
        
        let isDownloaded = downloadManager.isBookDownloaded(book.id)
        
        let fullBook: Book
        
        if isDownloaded {
            do {
                fullBook = try loadLocalMetadata(bookId: book.id, downloadManager: downloadManager)
                AppLogger.debug.debug("[PlayBookUseCase] Loaded book from local metadata: \(fullBook.title)")
            } catch {
                AppLogger.debug.debug("[PlayBookUseCase] Failed to load local metadata, trying online: \(error)")
                do {
                    fullBook = try await api.fetchBookDetails(bookId: book.id)
                } catch {
                    throw PlayBookError.fetchFailed(error)
                }
            }
        } else {
            do {
                fullBook = try await api.fetchBookDetails(bookId: book.id)
            } catch {
                throw PlayBookError.fetchFailed(error)
            }
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
        
        await MainActor.run {
            switch playbackMode {
            case .online:
                player.load(book: fullBook, isOffline: false, restoreState: restoreState)
                AppLogger.debug.debug("[PlayBookUseCase] Loaded book: \(fullBook.title) (mode: online)")
                
            case .offline:
                player.load(book: fullBook, isOffline: true, restoreState: restoreState)
                AppLogger.debug.debug("[PlayBookUseCase] Loaded book: \(fullBook.title) (mode: offline)")
                
            case .unavailable:
                break
            }
        }

        if playbackMode == .unavailable {
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
    
    private func loadLocalMetadata(bookId: String, downloadManager: DownloadManager) throws -> Book {
        let bookDir = downloadManager.bookDirectory(for: bookId)
        let metadataURL = bookDir.appendingPathComponent("metadata.json")
        
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            throw PlayBookError.fetchFailed(NSError(
                domain: "PlayBookUseCase",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Local metadata not found"]
            ))
        }
        
        let data = try Data(contentsOf: metadataURL)
        let book = try JSONDecoder().decode(Book.self, from: data)
        
        return book
    }
}
