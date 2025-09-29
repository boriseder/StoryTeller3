//
//  AppStateManager.swift
//  StoryTeller3
//
//  Created by Boris Eder on 09.09.25.
//
import SwiftUI

class AppStateManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isFirstLaunch: Bool = false
    @Published var apiClient: AudiobookshelfAPI?
    @Published var showingWelcome = false
    @Published var showingSettings = false

    // MARK: - Initialization
    init() {
        checkFirstLaunch()
    }
    
    // MARK: - Private Methods
    
    /**
     * Check if this is the app's first launch
     */
    private func checkFirstLaunch() {
        let hasLaunchedKey = "has_launched_before"
        isFirstLaunch = !UserDefaults.standard.bool(forKey: hasLaunchedKey)
        
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            setupDefaultCacheSettings() // ← Neu hinzugefügt
        }
    }
        
    /**
     * Setup default cache settings on first launch
     */
    private func setupDefaultCacheSettings() {
        let defaults = UserDefaults.standard
        
        // Set default cache settings if not already set
        if defaults.coverCacheLimit == 0 {
            defaults.coverCacheLimit = 100
        }
        
        if defaults.memoryCacheSize == 0 {
            defaults.memoryCacheSize = 50
        }
        
        // Enable optimization by default
        defaults.cacheOptimizationEnabled = true
        defaults.autoCacheCleanup = true
        
        AppLogger.debug.debug("[App] Default cache settings applied")
    }
}
