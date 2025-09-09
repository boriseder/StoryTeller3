//
//  SleepTimerViewModel.swift
//  StoryTeller3
//
//  Created by Boris Eder on 09.09.25.
//


//
//  SleepTimerViewModel.swift
//  StoryTeller3
//
//  Created by Boris Eder on 09.09.25.
//

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
        timer?.invalidate()
        timer = nil
        isTimerActive = false
        remainingTime = 0
    }
    
    private func finishTimer() {
        player.pause()
        cancelTimer()
    }
    
    deinit {
        timer?.invalidate()
    }
}