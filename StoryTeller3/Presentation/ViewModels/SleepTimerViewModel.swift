import SwiftUI

// MARK: - Sleep Timer ViewModel
class SleepTimerViewModel: BaseViewModel {
    @Published var selectedMinutes: Int = 30
    @Published var isTimerActive = false
    @Published var remainingTime: TimeInterval = 0
    
    private var timer: Timer?
    private let player: AudioPlayer
    private let timerOptions = [5, 10, 15, 30, 45, 60, 90, 120]
    
    init(player: AudioPlayer) {
        self.player = player
        super.init()
    }
    
    var timerOptionsArray: [Int] {
        timerOptions
    }
    
    func startTimer(minutes: Int) {
        guard minutes > 0 else {
            AppLogger.debug.debug("[SleepTimer] Invalid timer duration: \(minutes)")
            return
        }
        
        // Cancel any existing timer
        cancelTimer()
        
        remainingTime = TimeInterval(minutes * 60)
        isTimerActive = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.remainingTime -= 1
                
                if self.remainingTime <= 0 {
                    self.finishTimer()
                }
            }
        }
    }
    
    func cancelTimer() {
        AppLogger.debug.debug("[SleepTimer] Timer cancelled")
        timer?.invalidate()
        timer = nil
        isTimerActive = false
        remainingTime = 0
    }
    
    private func finishTimer() {
        AppLogger.debug.debug("[SleepTimer] Timer finished - pausing playback")
        
        // Pause the player
        player.pause()
        
        // Clean up timer state
        cancelTimer()
        
        // Optional: Could add haptic feedback or notification here
        #if !targetEnvironment(simulator)
        // Add subtle haptic feedback on real device
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
        
        AppLogger.debug.debug("[SleepTimer] Sleep timer completed successfully")
    }
    
    deinit {
        timer?.invalidate()
        AppLogger.debug.debug("[SleepTimer] ViewModel deinitialized")
    }
}
