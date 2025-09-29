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
    
    // MARK: - App State
    @StateObject private var appState = AppStateManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    setupCacheManager() // ← Neu hinzugefügt
            }
        }
    }
    
    // MARK: - App Configuration
    
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
}

