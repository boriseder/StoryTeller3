import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Device Utilities
enum DeviceUtils {
    static func getDeviceIdentifier() -> String {
        #if canImport(UIKit)
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #elseif canImport(AppKit)
        let key = "DeviceIdentifier"
        if let savedIdentifier = UserDefaults.standard.string(forKey: key) {
            return savedIdentifier
        } else {
            let newIdentifier = UUID().uuidString
            UserDefaults.standard.set(newIdentifier, forKey: key)
            return newIdentifier
        }
        #else
        return UUID().uuidString
        #endif
    }
    
    static func createPlaybackRequest() -> PlaybackSessionRequest {
        PlaybackSessionRequest(
            deviceInfo: PlaybackSessionRequest.DeviceInfo(
                clientVersion: "1.0.0",
                deviceId: getDeviceIdentifier(),
                clientName: getClientName()
            ),
            supportedMimeTypes: ["audio/mpeg", "audio/mp4", "audio/m4a", "audio/flac"],
            mediaPlayer: "AVPlayer"
        )
    }
    
    private static func getClientName() -> String {
        #if os(iOS)
        return "iOS AudioBook Client"
        #elseif os(macOS)
        return "macOS AudioBook Client"
        #else
        return "AudioBook Client"
        #endif
    }
}