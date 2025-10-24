import SwiftUI

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

@MainActor
class ContinueReadingViewModel: ObservableObject {
    @Published var recentBooks: [PlaybackState] = []
    @Published var syncStatus: SyncStatus = .idle
    
    private let persistenceManager = PlaybackPersistenceManager.shared
    private let syncProgressUseCase: SyncProgressUseCaseProtocol
    
    init(syncProgressUseCase: SyncProgressUseCaseProtocol) {
        self.syncProgressUseCase = syncProgressUseCase
    }
    
    func loadRecentBooks() {
        recentBooks = persistenceManager.getRecentlyPlayed(limit: 10)
            .filter { !$0.isFinished }
    }
    
    func sync() async {
        guard !syncStatus.isActive else { return }
        
        syncStatus = .syncing
        
        do {
            try await syncProgressUseCase.execute()
            syncStatus = .success(Date())
            loadRecentBooks()
        } catch {
            syncStatus = .failed(error)
            AppLogger.general.debug("[ContinueReading] Sync failed: \(error)")
        }
    }
    
    func getProgressText(for state: PlaybackState) -> String {
        let progressPercent = Int(state.progress * 100)
        return "\(progressPercent)% • Chapter \(state.chapterIndex + 1)"
    }
    
    func getTimeAgoText(for state: PlaybackState) -> String {
        let timeInterval = Date().timeIntervalSince(state.lastPlayed)
        
        if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes) min ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
}
