//
//  AppStateManager.swift
//  StoryTeller3
//
//  Created by Boris Eder on 09.09.25.
//
import SwiftUI

class AppStateManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentTheme: AppTheme = .automatic
    @Published var isFirstLaunch: Bool = false
    @Published var apiClient: AudiobookshelfAPI?
    @Published var showingWelcome = false
    @Published var showingSettings = false

    // MARK: - Initialization
    init() {
        checkFirstLaunch()
        loadThemePreference()
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
     * Load theme preference from UserDefaults
     */
    private func loadThemePreference() {
        if let themeRawValue = UserDefaults.standard.string(forKey: "app_theme"),
           let theme = AppTheme(rawValue: themeRawValue) {
            currentTheme = theme
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
        
        print("[App] Default cache settings applied")
    }
    
    // MARK: - Public Methods
    
    /**
     * Update the app theme preference
     */
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "app_theme")
        
        // Apply theme immediately
        applyThemeToWindows(theme)
    }
    
    /**
     * Apply theme to all app windows
     */
    private func applyThemeToWindows(_ theme: AppTheme) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        
        for window in windowScene.windows {
            switch theme {
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            case .automatic:
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
}
