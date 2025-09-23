import SwiftUI

/**
 * StoryTeller2App - Main application entry point
 *
 * A modern iOS client for Audiobookshelf servers featuring:
 * - Library browsing and streaming
 * - Offline downloads with progress tracking
 * - Customizable themes (light/dark/automatic)
 * - Server and library statistics
 * - Advanced settings and cache management
 */
@main
struct StoryTeller3App: App {
    
    // apikey
    // "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJrZXlJZCI6Ijk0OGUyY2IxLWVmMGMtNDc4YS05M2Y1LThhZDExMGM2NjE3ZiIsIm5hbWUiOiJTdG9yeVRlbGxlcjMiLCJ0eXBlIjoiYXBpIiwiaWF0IjoxNzU4NjQwODAzfQ.s5DeAj5HAmIOAyNBsxl2VGG5RkWIcHLYh8M2R57HAeQ"
    
    // MARK: - App State
    @StateObject private var appState = AppStateManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    configureAppearance()
                    loadUserPreferences()
                    setupCacheManager() // ← Neu hinzugefügt
                }
        }
    }
    
    // MARK: - App Configuration
    
    /**
     * Configure global app appearance and styling
     */
    private func configureAppearance() {
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Set accent color for system components
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor.systemBlue
    }
    
    /**
     * Load saved user preferences and apply them
     */
    private func loadUserPreferences() {
        // Load and apply theme preference
        if let themeRawValue = UserDefaults.standard.string(forKey: "app_theme"),
           let theme = AppTheme(rawValue: themeRawValue) {
            applyTheme(theme)
        } else {
            // Default to automatic theme
            UserDefaults.standard.set(AppTheme.automatic.rawValue, forKey: "app_theme")
        }
    }
    
    /**
     * Setup cache manager with saved settings
     */
    private func setupCacheManager() {
        // Apply saved cache settings on app launch
        Task { @MainActor in
            CoverCacheManager.shared.updateCacheLimits()
            
            // Enable automatic cache optimization if set
            if UserDefaults.standard.bool(forKey: "cache_optimization_enabled") {
                await CoverCacheManager.shared.optimizeCache()
            }
            
            AppLogger.debug.debug("[App] Cache manager initialized")
        }
    }
    
    /**
     * Apply the selected theme to all app windows
     */
    private func applyTheme(_ theme: AppTheme) {
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

