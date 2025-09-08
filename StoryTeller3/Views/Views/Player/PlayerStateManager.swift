import SwiftUI

class PlayerStateManager: ObservableObject {
    @Published var showFullscreenPlayer: Bool = false
    @Published var showMiniPlayer: Bool = false
    
    func showFullscreen() {
        showFullscreenPlayer = true
        showMiniPlayer = false
    }
    
    func showMini() {
        showFullscreenPlayer = false
        showMiniPlayer = true
    }
    
    func dismissFullscreen() {
        showFullscreenPlayer = false
        showMiniPlayer = true
    }
    
    func hideMiniPlayer() {
        showMiniPlayer = false
    }
    
    func updatePlayerState(hasBook: Bool) {
        // Wenn kein Buch geladen ist, beide Player verstecken
        if !hasBook {
            showFullscreenPlayer = false
            showMiniPlayer = false
        }
        // Wenn ein Buch geladen ist und kein Player sichtbar ist, MiniPlayer zeigen
        else if !showFullscreenPlayer && !showMiniPlayer {
            showMiniPlayer = true
        }
    }
    
    // Neue Convenience-Methoden
    func toggleMiniPlayer() {
        showMiniPlayer.toggle()
    }
    
    func reset() {
        showFullscreenPlayer = false
        showMiniPlayer = false
    }
    
    // Getter für UI-Status
    var isPlayerVisible: Bool {
        showFullscreenPlayer || showMiniPlayer
    }
    
    var playerMode: PlayerMode {
        if showFullscreenPlayer {
            return .fullscreen
        } else if showMiniPlayer {
            return .mini
        } else {
            return .hidden
        }
    }
}

enum PlayerMode {
    case hidden
    case mini
    case fullscreen
}
