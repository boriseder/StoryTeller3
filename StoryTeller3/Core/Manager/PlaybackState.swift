import Foundation

// MARK: - Playback State Model
struct PlaybackState {
    let bookId: String
    let chapterIndex: Int
    let currentTime: Double
    let duration: Double
    let lastPlayed: Date
    let isFinished: Bool
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
}

// MARK: - Playback Persistence Manager (UserDefaults only)
class PlaybackPersistenceManager: ObservableObject {
    static let shared = PlaybackPersistenceManager()
    
    private let userDefaults = UserDefaults.standard
    private let autoSaveInterval: TimeInterval = 30.0
    private var autoSaveTimer: Timer?
    private let queue = DispatchQueue(label: "com.storyteller.playback.persistence", attributes: .concurrent)
    
    private init() {
        startAutoSave()
    }
    
    // MARK: - Save Playback State
    func savePlaybackState(_ state: PlaybackState) {
        queue.async(flags: .barrier) {
            let key = "playback_\(state.bookId)"
            let data: [String: Any] = [
                "chapterIndex": state.chapterIndex,
                "currentTime": state.currentTime,
                "duration": state.duration,
                "lastPlayed": state.lastPlayed.timeIntervalSince1970,
                "isFinished": state.isFinished
            ]
            
            self.userDefaults.set(data, forKey: key)
            
            var allBookIds = self.userDefaults.stringArray(forKey: "all_playback_books") ?? []
            if !allBookIds.contains(state.bookId) {
                allBookIds.append(state.bookId)
                self.userDefaults.set(allBookIds, forKey: "all_playback_books")
            }
            
            AppLogger.debug.debug("[PlaybackPersistence] Saved state for book: \(state.bookId)")
        }
    }
    
    // MARK: - Load Playback State
    func loadPlaybackState(for bookId: String) -> PlaybackState? {
        return queue.sync {
            let key = "playback_\(bookId)"
            guard let data = self.userDefaults.dictionary(forKey: key) else { return nil }
            
            return PlaybackState(
                bookId: bookId,
                chapterIndex: data["chapterIndex"] as? Int ?? 0,
                currentTime: data["currentTime"] as? Double ?? 0,
                duration: data["duration"] as? Double ?? 0,
                lastPlayed: Date(timeIntervalSince1970: data["lastPlayed"] as? TimeInterval ?? 0),
                isFinished: data["isFinished"] as? Bool ?? false
            )
        }
    }
    
    // MARK: - Get All Progress
    func getAllPlaybackStates() -> [PlaybackState] {
        return queue.sync {
            guard let allBookIds = self.userDefaults.stringArray(forKey: "all_playback_books") else {
                return []
            }
            
            return allBookIds.compactMap { bookId in
                self.loadPlaybackStateInternal(for: bookId)
            }
        }
    }
    
    private func loadPlaybackStateInternal(for bookId: String) -> PlaybackState? {
        let key = "playback_\(bookId)"
        guard let data = self.userDefaults.dictionary(forKey: key) else { return nil }
        
        return PlaybackState(
            bookId: bookId,
            chapterIndex: data["chapterIndex"] as? Int ?? 0,
            currentTime: data["currentTime"] as? Double ?? 0,
            duration: data["duration"] as? Double ?? 0,
            lastPlayed: Date(timeIntervalSince1970: data["lastPlayed"] as? TimeInterval ?? 0),
            isFinished: data["isFinished"] as? Bool ?? false
        )
    }
    
    // MARK: - Recently Played
    func getRecentlyPlayed(limit: Int = 10) -> [PlaybackState] {
        let allStates = getAllPlaybackStates()
        let sortedStates = allStates.sorted { $0.lastPlayed > $1.lastPlayed }
        return Array(sortedStates.prefix(limit))
    }
    
    // MARK: - Delete State
    func deletePlaybackState(for bookId: String) {
        queue.async(flags: .barrier) {
            let key = "playback_\(bookId)"
            self.userDefaults.removeObject(forKey: key)
            
            var allBookIds = self.userDefaults.stringArray(forKey: "all_playback_books") ?? []
            allBookIds.removeAll { $0 == bookId }
            self.userDefaults.set(allBookIds, forKey: "all_playback_books")
            
            AppLogger.debug.debug("[PlaybackPersistence] Deleted state for book: \(bookId)")
        }
    }
    
    // MARK: - Clear All
    func clearAllPlaybackStates() {
        queue.async(flags: .barrier) {
            guard let allBookIds = self.userDefaults.stringArray(forKey: "all_playback_books") else {
                return
            }
            
            for bookId in allBookIds {
                let key = "playback_\(bookId)"
                self.userDefaults.removeObject(forKey: key)
            }
            
            self.userDefaults.removeObject(forKey: "all_playback_books")
            
            AppLogger.debug.debug("[PlaybackPersistence] Cleared all playback states")
        }
    }
    
    // MARK: - Auto-Save
    private func startAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { _ in
            self.performAutoSave()
        }
    }
    
    private func performAutoSave() {
        NotificationCenter.default.post(name: .playbackAutoSave, object: nil)
    }
    
    deinit {
        autoSaveTimer?.invalidate()
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let playbackAutoSave = Notification.Name("playbackAutoSave")
    static let playbackStateChanged = Notification.Name("playbackStateChanged")
}
