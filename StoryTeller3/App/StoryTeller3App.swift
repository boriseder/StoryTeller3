import SwiftUI

@main
struct StoryTeller3App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var appState = AppStateManager()
    @StateObject private var theme = ThemeManager()

    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(theme)
                .preferredColorScheme(theme.colorScheme)
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
            
            AppLogger.general.info("[App] Cache manager initialized")
        }
    }
}
