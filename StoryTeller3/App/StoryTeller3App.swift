import SwiftUI

@main
struct StoryTeller3App: App {
    // ✅ Add AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var appState = AppStateManager()
    @State private var terminationObserver: NSObjectProtocol?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    setupCacheManager()
                }
        }
    }
    
    init() {
        // No longer need setupTerminationHandler - AppDelegate handles it
        AppLogger.debug.debug("[App] ✅ App initialized")
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
