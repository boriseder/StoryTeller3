//
//  PlayerViewModel.swift
//  StoryTeller3
//
//  Created by Boris Eder on 09.09.25.
//

import SwiftUI

// MARK: - Player ViewModel
class PlayerViewModel: BaseViewModel {
    @Published var showingChaptersList = false
    @Published var showingSleepTimer = false
    @Published var showingPlaybackSettings = false
    @Published var isDraggingSlider = false
    @Published var sliderValue: Double = 0
    
    let player: AudioPlayer
    let api: AudiobookshelfAPI
    
    init(player: AudioPlayer, api: AudiobookshelfAPI) {
        self.player = player
        self.api = api
        super.init()
        
        self.sliderValue = player.currentTime
    }
    
    func updateSliderValue(_ newValue: Double) {
        sliderValue = newValue
        if !isDraggingSlider {
            player.seek(to: newValue)
        }
    }
    
    func onSliderEditingChanged(_ editing: Bool) {
        isDraggingSlider = editing
        if !editing {
            player.seek(to: sliderValue)
        }
    }
    
    func updateSliderFromPlayer(_ time: Double) {
        if !isDraggingSlider {
            sliderValue = time
        }
    }
}
