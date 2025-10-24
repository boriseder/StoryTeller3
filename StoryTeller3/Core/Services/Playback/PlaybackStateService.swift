import Foundation
import UIKit

protocol PlaybackStateService {
    func saveState(_ state: PlaybackState)
    func loadState(for bookId: String) -> PlaybackState?
    func setupAutoSave(onSave: @escaping () -> Void)
}

class DefaultPlaybackStateService: PlaybackStateService {
    private var observers: [NSObjectProtocol] = []
    
    func saveState(_ state: PlaybackState) {
        PlaybackPersistenceManager.shared.savePlaybackState(state)
    }
    
    func loadState(for bookId: String) -> PlaybackState? {
        return PlaybackPersistenceManager.shared.loadPlaybackState(for: bookId)
    }
    
    func setupAutoSave(onSave: @escaping () -> Void) {
        let autoSaveObserver = NotificationCenter.default.addObserver(
            forName: .playbackAutoSave,
            object: nil,
            queue: .main
        ) { _ in
            onSave()
        }
        observers.append(autoSaveObserver)
        
        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            onSave()
        }
        observers.append(backgroundObserver)
    }
    
    deinit {
        observers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }
}
