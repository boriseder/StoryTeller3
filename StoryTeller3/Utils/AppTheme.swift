 import Foundation

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case automatic = "automatic"
    
    var displayName: String {
        switch self {
        case .light:
            return "Hell"
        case .dark:
            return "Dunkel"
        case .automatic:
            return "Automatisch"
        }
    }
}
