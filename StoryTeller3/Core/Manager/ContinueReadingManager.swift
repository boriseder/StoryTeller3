import SwiftUI

// MARK: - Continue Reading Manager
@MainActor
class ContinueReadingManager: ObservableObject {
    @Published var recentBooks: [PlaybackState] = []
    
    private let repository = PlaybackRepository.shared
    
    func loadRecentBooks() {
        recentBooks = repository.getRecentlyPlayed(limit: 10)
    }

    func getProgressText(for state: PlaybackState) -> String {
        let progressPercent = Int(state.progress * 100)
        return "\(progressPercent)% • Chapter \(state.chapterIndex + 1)"
    }
    
    func getTimeAgoText(for state: PlaybackState) -> String {
        let timeInterval = Date().timeIntervalSince(state.lastPlayed)
        
        if timeInterval < 3600 { // Less than 1 hour
            let minutes = Int(timeInterval / 60)
            return "\(minutes) min ago"
        } else if timeInterval < 86400 { // Less than 24 hours
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
}

