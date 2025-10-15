import Foundation

// MARK: - Repository Protocol
protocol PlaybackRepositoryProtocol {
    func getPlaybackState(for bookId: String) -> PlaybackState?
    func savePlaybackState(_ state: PlaybackState)
    func getRecentlyPlayed(limit: Int) -> [PlaybackState]
    func getAllPlaybackStates() -> [PlaybackState]
    func deletePlaybackState(for bookId: String)
    func clearAllPlaybackStates()
    func syncPlaybackProgress(to server: AudiobookshelfAPI) async throws
}

// MARK: - Playback Repository Implementation
class PlaybackRepository: PlaybackRepositoryProtocol {
    
    private let persistenceManager: PlaybackPersistenceManager
    
    init(persistenceManager: PlaybackPersistenceManager = .shared) {
        self.persistenceManager = persistenceManager
    }
    
    // MARK: - State Management
    
    func getPlaybackState(for bookId: String) -> PlaybackState? {
        persistenceManager.loadPlaybackState(for: bookId)
    }
    
    func savePlaybackState(_ state: PlaybackState) {
        persistenceManager.savePlaybackState(state)
        AppLogger.debug.debug("[PlaybackRepository] Saved state for book: \(state.bookId)")
    }
    
    func getRecentlyPlayed(limit: Int) -> [PlaybackState] {
        persistenceManager.getRecentlyPlayed(limit: limit)
    }
    
    func getAllPlaybackStates() -> [PlaybackState] {
        persistenceManager.getAllPlaybackStates()
    }
    
    func deletePlaybackState(for bookId: String) {
        persistenceManager.deletePlaybackState(for: bookId)
        AppLogger.debug.debug("[PlaybackRepository] Deleted state for book: \(bookId)")
    }
    
    func clearAllPlaybackStates() {
        let states = getAllPlaybackStates()
        for state in states {
            persistenceManager.deletePlaybackState(for: state.bookId)
        }
        AppLogger.debug.debug("[PlaybackRepository] Cleared all playback states")
    }
    
    // MARK: - Server Sync
    
    func syncPlaybackProgress(to server: AudiobookshelfAPI) async throws {
        let states = getAllPlaybackStates()
        
        for state in states {
            do {
                try await uploadProgress(state, to: server)
                AppLogger.debug.debug("[PlaybackRepository] Synced progress for: \(state.bookId)")
            } catch {
                AppLogger.debug.debug("[PlaybackRepository] Failed to sync \(state.bookId): \(error)")
                throw PlaybackError.syncFailed(state.bookId, error)
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func uploadProgress(_ state: PlaybackState, to api: AudiobookshelfAPI) async throws {
        let url = URL(string: "\(api.baseURLString)/api/me/progress/\(state.bookId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(api.authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let progressData: [String: Any] = [
            "currentTime": state.currentTime,
            "duration": state.duration,
            "progress": state.progress,
            "isFinished": state.isFinished
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: progressData)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PlaybackError.uploadFailed
        }
    }
}

// MARK: - Playback Errors
enum PlaybackError: LocalizedError {
    case stateNotFound
    case saveFailed
    case syncFailed(String, Error)
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .stateNotFound:
            return "Playback state not found"
        case .saveFailed:
            return "Failed to save playback state"
        case .syncFailed(let bookId, let error):
            return "Failed to sync \(bookId): \(error.localizedDescription)"
        case .uploadFailed:
            return "Failed to upload progress to server"
        }
    }
}
