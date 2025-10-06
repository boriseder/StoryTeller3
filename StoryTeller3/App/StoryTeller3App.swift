import SwiftUI

@main
struct StoryTeller3App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var appState = AppStateManager()
    @StateObject private var appConfig = AppConfig.shared 
    @State private var terminationObserver: NSObjectProtocol?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appConfig)
                .accentColor(appConfig.userAccentColor.color)
                .onAppear {
                    setupCacheManager()
                }
        }
    }
    
    init() {
        // No longer need setupTerminationHandler - AppDelegate handles it
        AppLogger.debug.debug("[App] App initialized")
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
