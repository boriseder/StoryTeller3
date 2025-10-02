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

import SwiftUI

@main
struct StoryTeller3App: App {
    @StateObject private var appState = AppStateManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    setupCacheManager()
                }
        }
    }
    
    private func setupCacheManager() {
        Task { @MainActor in
            CoverCacheManager.shared.updateCacheLimits()
            
            if UserDefaults.standard.bool(forKey: "cache_optimization_enabled") {
                await CoverCacheManager.shared.optimizeCache()
            }
            
            AppLogger.debug.debug("[App] Cache manager initialized")
        }
    }
}
