import UIKit
import SwiftUI
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        
        configureAudioSession()
        
        AppLogger.general.debug("[AppDelegate] App launched successfully")
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        AppLogger.general.debug("[AppDelegate] 🔴 App will terminate - saving state")
        
        NotificationCenter.default.post(name: .playbackAutoSave, object: nil)
        Thread.sleep(forTimeInterval: 0.5)
        
        AppLogger.general.debug("[AppDelegate] State saved before termination")
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        AppLogger.general.debug("[AppDelegate] ⚠️ Memory warning received - triggering cleanup")
        
        Task { @MainActor in
            CoverCacheManager.shared.triggerCriticalCleanup()
        }
        
        Task {
            await CoverDownloadManager.shared.cancelAllDownloads()
        }
        
        AppLogger.general.debug("[AppDelegate] Memory cleanup completed")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        AppLogger.general.debug("[AppDelegate] 📱 App entered background")
        
        NotificationCenter.default.post(name: .playbackAutoSave, object: nil)
        
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = application.beginBackgroundTask {
            application.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        DispatchQueue.global(qos: .background).async {
            if UserDefaults.standard.bool(forKey: "auto_cache_cleanup") {
                Task {
                    await CoverCacheManager.shared.optimizeCache()
                }
            }
            
            application.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        AppLogger.general.debug("[AppDelegate] 📱 App will enter foreground")
        NotificationCenter.default.post(name: .init("AppWillEnterForeground"), object: nil)
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        AppLogger.general.debug("[AppDelegate] App became active")
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        AppLogger.general.debug("[AppDelegate] ⏸️ App will resign active")
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio)
            try audioSession.setActive(true)
            
            AppLogger.general.debug("[AppDelegate] Audio session configured")
            
        } catch {
            AppLogger.general.debug("[AppDelegate] ❌ Failed to configure audio session: \(error)")
        }
    }
}
