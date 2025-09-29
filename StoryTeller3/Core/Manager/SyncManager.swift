import Foundation
import Combine
import UIKit

// MARK: - Sync Status
enum SyncStatus {
    case idle
    case syncing
    case success(Date)
    case failed(Error)
    
    var isActive: Bool {
        if case .syncing = self { return true }
        return false
    }
}

// MARK: - Sync Conflict Resolution
enum ConflictResolution {
    case useLocal      // Prefer local changes
    case useRemote     // Prefer server changes
    case useNewest     // Use most recent timestamp
    case manual        // Let user decide
}

// MARK: - Syncable Data Models
protocol Syncable {
    var id: String { get }
    var lastModified: Date { get }
    var syncStatus: SyncItemStatus { get set }
}

enum SyncItemStatus {
    case synced
    case pendingUpload
    case pendingDownload
    case conflict
}

// MARK: - Sync Manager
class OfflineSyncManager: ObservableObject {
    static let shared = OfflineSyncManager()
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var pendingUploads: Int = 0
    @Published var pendingDownloads: Int = 0
    
    private let persistenceManager = PlaybackPersistenceManager.shared
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // Sync configuration
    private let conflictResolution: ConflictResolution = .useNewest
    private let autoSyncInterval: TimeInterval = 300 // 5 minutes
    private var autoSyncTimer: Timer?
    
    private init() {
        setupAutoSync()
        observeNetworkChanges()
    }
    
    // MARK: - Auto Sync Setup
    private func setupAutoSync() {
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: autoSyncInterval, repeats: true) { _ in
            Task { await self.performSync() }
        }
        
        // Sync when app becomes active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Sync when network becomes available
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkBecameAvailable),
            name: .networkAvailable,
            object: nil
        )
    }
    
    @objc private func appBecameActive() {
        Task { await performSync() }
    }
    
    @objc private func networkBecameAvailable() {
        Task { await performSync() }
    }
    
    // MARK: - Main Sync Method
    func performSync() async {
        guard !syncStatus.isActive else {
            AppLogger.debug.debug("[OfflineSync] Sync already in progress")
            return
        }
        
        await MainActor.run {
            syncStatus = .syncing
        }
        
        do {
            // 1. Upload local changes
            try await uploadLocalChanges()
            
            // 2. Download server changes
            try await downloadServerChanges()
            
            // 3. Resolve conflicts
            try await resolveConflicts()
            
            await MainActor.run {
                syncStatus = .success(Date())
                updatePendingCounts()
            }
            
            AppLogger.debug.debug("[OfflineSync] Sync completed successfully")
            
        } catch {
            await MainActor.run {
                syncStatus = .failed(error)
            }
            AppLogger.debug.debug("[OfflineSync] Sync failed: \(error)")
        }
    }
    
    // MARK: - Upload Local Changes
    private func uploadLocalChanges() async throws {
        let localStates = persistenceManager.getAllPlaybackStates()
        let pendingStates = localStates.filter { needsUpload($0) }
        
        AppLogger.debug.debug("[OfflineSync] Uploading \(pendingStates.count) local changes")
        
        for state in pendingStates {
            try await uploadPlaybackState(state)
            markAsUploaded(state)
        }
        
        await MainActor.run {
            pendingUploads = 0
        }
    }
    
    private func needsUpload(_ state: PlaybackState) -> Bool {
        let lastUpload = getLastUploadTime(for: state.bookId)
        return state.lastPlayed > lastUpload
    }
    
    private func uploadPlaybackState(_ state: PlaybackState) async throws {
        // Implement your server API call here
        // This is a placeholder implementation
        
        let url = URL(string: "https://your-server.com/api/progress/\(state.bookId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let uploadData: [String: Any] = [
            "chapterIndex": state.chapterIndex,
            "currentTime": state.currentTime,
            "duration": state.duration,
            "lastPlayed": state.lastPlayed.iso8601String,
            "isFinished": state.isFinished
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: uploadData)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SyncError.uploadFailed
        }
        
        AppLogger.debug.debug("[OfflineSync] Uploaded state for book: \(state.bookId)")
    }
    
    // MARK: - Download Server Changes
    private func downloadServerChanges() async throws {
        let lastSync = getLastSyncTime()
        let serverStates = try await fetchServerChanges(since: lastSync)
        
        AppLogger.debug.debug("[OfflineSync] Downloaded \(serverStates.count) server changes")
        
        for serverState in serverStates {
            processServerState(serverState)
        }
        
        setLastSyncTime(Date())
        
        await MainActor.run {
            pendingDownloads = 0
        }
    }
    
    private func processServerState(_ state: PlaybackState) {
        // Compare with local state and update if newer
        if let localState = persistenceManager.loadPlaybackState(for: state.bookId) {
            if state.lastPlayed > localState.lastPlayed {
                // Server state is newer, update local
                persistenceManager.savePlaybackState(state)
                AppLogger.debug.debug("[OfflineSync] Updated local state for: \(state.bookId)")
            }
        } else {
            // No local state, save server state
            persistenceManager.savePlaybackState(state)
            AppLogger.debug.debug("[OfflineSync] Saved new state from server: \(state.bookId)")
        }
    }
    
    private func fetchServerChanges(since date: Date) async throws -> [PlaybackState] {
        // Implement your server API call here
        let url = URL(string: "https://your-server.com/api/progress?since=\(date.iso8601String)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SyncError.downloadFailed
        }
        
        // Parse response and convert to PlaybackState array
        // This is a placeholder implementation
        return []
    }
    
    // MARK: - Conflict Resolution
    private func resolveConflicts() async throws {
        let conflicts = findConflicts()
        
        for conflict in conflicts {
            let resolution = try await resolveConflict(conflict)
            applyResolution(resolution, for: conflict)
        }
    }
    
    private func applyResolution(_ resolution: ConflictResolution, for conflict: SyncConflict) {
        switch resolution {
        case .useLocal:
            // Keep local state, upload to server
            AppLogger.debug.debug("[OfflineSync] Resolving conflict: using local for \(conflict.bookId)")
            persistenceManager.savePlaybackState(conflict.localState)
        case .useRemote:
            // Use server state, update local
            AppLogger.debug.debug("[OfflineSync] Resolving conflict: using remote for \(conflict.bookId)")
            persistenceManager.savePlaybackState(conflict.serverState)
        case .useNewest:
            // Already handled in resolveConflict
            break
        case .manual:
            // Manual resolution would require UI interaction
            AppLogger.debug.debug("[OfflineSync] Manual conflict resolution needed for \(conflict.bookId)")
        }
    }
    
    private func findConflicts() -> [SyncConflict] {
        // Find items that have been modified both locally and on server
        // This is a simplified implementation
        return []
    }
    
    private func resolveConflict(_ conflict: SyncConflict) async throws -> ConflictResolution {
        switch conflictResolution {
        case .useLocal:
            return .useLocal
        case .useRemote:
            return .useRemote
        case .useNewest:
            return conflict.localState.lastPlayed > conflict.serverState.lastPlayed ? .useLocal : .useRemote
        case .manual:
            // In a real implementation, show UI for user to choose
            return .useNewest
        }
    }
    
    // MARK: - Utility Methods
    private func updatePendingCounts() {
        let localStates = persistenceManager.getAllPlaybackStates()
        pendingUploads = localStates.filter { needsUpload($0) }.count
        // Update pending downloads count based on your implementation
    }
    
    private func getLastUploadTime(for bookId: String) -> Date {
        let key = "last_upload_\(bookId)"
        let timestamp = userDefaults.double(forKey: key)
        return Date(timeIntervalSince1970: timestamp)
    }
    
    private func markAsUploaded(_ state: PlaybackState) {
        let key = "last_upload_\(state.bookId)"
        userDefaults.set(state.lastPlayed.timeIntervalSince1970, forKey: key)
    }
    
    private func getLastSyncTime() -> Date {
        let timestamp = userDefaults.double(forKey: "last_sync_time")
        return Date(timeIntervalSince1970: timestamp)
    }
    
    private func setLastSyncTime(_ date: Date) {
        userDefaults.set(date.timeIntervalSince1970, forKey: "last_sync_time")
    }
    
    private func getAuthToken() -> String {
        // Get from your authentication system
        return UserDefaults.standard.string(forKey: "auth_token") ?? ""
    }
    
    private func observeNetworkChanges() {
        // Implement network reachability monitoring
        // When network becomes available, trigger sync
    }
    
    deinit {
        autoSyncTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Types
struct SyncConflict {
    let bookId: String
    let localState: PlaybackState
    let serverState: PlaybackState
}

enum SyncError: LocalizedError {
    case uploadFailed
    case downloadFailed
    case conflictResolution
    
    var errorDescription: String? {
        switch self {
        case .uploadFailed: return "Failed to upload local changes"
        case .downloadFailed: return "Failed to download server changes"
        case .conflictResolution: return "Failed to resolve sync conflicts"
        }
    }
}

// MARK: - Extensions
extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

extension Notification.Name {
    static let networkAvailable = Notification.Name("networkAvailable")
    static let syncCompleted = Notification.Name("syncCompleted")
}
