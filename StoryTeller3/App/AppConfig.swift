import SwiftUI

class AppConfig: ObservableObject {
    @Published var userBackgroundStyle: UserBackgroundStyle {
        didSet {
            UserDefaults.standard.set(userBackgroundStyle.rawValue, forKey: "userBackgroundStyle")
        }
    }
    
    @Published var userAccentColor: UserAccentColor = .blue {
        didSet {
            UserDefaults.standard.set(userAccentColor.rawValue, forKey: "userAccentColor")
        }
    }
    
    init() {
        let cachedStyle = UserDefaults.standard.string(forKey: "userBackgroundStyle")
        let cachedColor = UserDefaults.standard.string(forKey: "userAccentColor")
        
        self.userBackgroundStyle = cachedStyle.flatMap(UserBackgroundStyle.init) ?? .dynamic
        self.userAccentColor = cachedColor.flatMap(UserAccentColor.init) ?? .blue
    }
}

enum UserBackgroundStyle: String, CaseIterable {
    case dynamic
    case light
    case dark
    
    var textColor: Color {
        switch self {
        case .dynamic, .dark:
            return .white
        case .light:
            return .black
        }
    }
}

enum UserAccentColor: String, CaseIterable, Identifiable {
    case red, orange, green, blue, purple, pink
    
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        }
    }
}
