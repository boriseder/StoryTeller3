//
//  AppDelegate.swift
//  StoryTeller3
//
//  Handles app lifecycle events for proper background audio and state management
//

import UIKit
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        
        // Configure audio session early for background playback
        configureAudioSession()
        
        AppLogger.debug.debug("[AppDelegate] ✅ App launched successfully")
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        AppLogger.debug.debug("[AppDelegate] 🔴 App will terminate - saving state")
        
        // Force save playback state
        NotificationCenter.default.post(name: .playbackAutoSave, object: nil)
        
        // Give it time to save (synchronous)
        Thread.sleep(forTimeInterval: 0.5)
        
        AppLogger.debug.debug("[AppDelegate] ✅ State saved before termination")
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        AppLogger.debug.debug("[AppDelegate] ⚠️ Memory warning received - triggering cleanup")
        
        // Trigger aggressive cache cleanup
        Task { @MainActor in
            CoverCacheManager.shared.triggerCriticalCleanup()
        }
        
        // Cancel any pending downloads
        Task {
            await CoverDownloadManager.shared.cancelAllDownloads()
        }
        
        AppLogger.debug.debug("[AppDelegate] ✅ Memory cleanup completed")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        AppLogger.debug.debug("[AppDelegate] 📱 App entered background")
        
        // Save playback state
        NotificationCenter.default.post(name: .playbackAutoSave, object: nil)
        
        // Begin background task for cleanup
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = application.beginBackgroundTask {
            application.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        // Perform cleanup
        DispatchQueue.global(qos: .background).async {
            // Clean up temporary files if needed
            if UserDefaults.standard.bool(forKey: "auto_cache_cleanup") {
                Task {
                    await CoverCacheManager.shared.optimizeCache()
                }
            }
            
            // End background task
            application.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        AppLogger.debug.debug("[AppDelegate] 📱 App will enter foreground")
        
        // Refresh data if needed
        NotificationCenter.default.post(name: .init("AppWillEnterForeground"), object: nil)
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        AppLogger.debug.debug("[AppDelegate] ✅ App became active")
        
        // Resume any paused activities
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        AppLogger.debug.debug("[AppDelegate] ⏸️ App will resign active")
        
        // Pause any active tasks that shouldn't run in background
    }
    
    // MARK: - Audio Session Configuration
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Configure for background playback
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [
                    .allowAirPlay,
                    .allowBluetooth,
                    .allowBluetoothA2DP,
                    .duckOthers
                ]
            )
            
            try audioSession.setActive(true)
            
            AppLogger.debug.debug("[AppDelegate] ✅ Audio session configured")
            
        } catch {
            AppLogger.debug.debug("[AppDelegate] ❌ Failed to configure audio session: \(error)")
        }
    }
}
