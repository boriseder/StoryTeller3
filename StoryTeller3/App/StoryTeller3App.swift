import SwiftUI

@main
struct StoryTeller3App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var appState = AppStateManager()
    @StateObject private var appConfig = AppConfig() 
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
        AppLogger.general.debug("[App] App initialized")
    }
    
    private func setupCacheManager() {
        Task { @MainActor in
            CoverCacheManager.shared.updateCacheLimits()
            
            if UserDefaults.standard.bool(forKey: "cache_optimization_enabled") {
                await CoverCacheManager.shared.optimizeCache()
            }
            
            AppLogger.general.debug("[App] Cache manager initialized")
        }
    }
}
