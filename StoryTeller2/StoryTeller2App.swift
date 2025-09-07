import SwiftUI

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
@main
struct StoryTeller2App: App {
    
    // MARK: - App State
    @StateObject private var appState = AppStateManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    configureAppearance()
                    loadUserPreferences()
                }
        }
    }
    
    // MARK: - App Configuration
    
    /**
     * Configure global app appearance and styling
     */
    private func configureAppearance() {
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Set accent color for system components
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor.systemBlue
    }
    
    /**
     * Load saved user preferences and apply them
     */
    private func loadUserPreferences() {
        // Load and apply theme preference
        if let themeRawValue = UserDefaults.standard.string(forKey: "app_theme"),
           let theme = AppTheme(rawValue: themeRawValue) {
            applyTheme(theme)
        } else {
            // Default to automatic theme
            UserDefaults.standard.set(AppTheme.automatic.rawValue, forKey: "app_theme")
        }
    }
    
    /**
     * Apply the selected theme to all app windows
     */
    private func applyTheme(_ theme: AppTheme) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        
        for window in windowScene.windows {
            switch theme {
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            case .automatic:
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
}

/**
 * AppStateManager - Centralized app state management
 *
 * Manages global app state including theme preferences,
 * first launch detection, and app-wide notifications
 */
class AppStateManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentTheme: AppTheme = .automatic
    @Published var isFirstLaunch: Bool = false
    
    // MARK: - Initialization
    init() {
        checkFirstLaunch()
        loadThemePreference()
    }
    
    // MARK: - Private Methods
    
    /**
     * Check if this is the app's first launch
     */
    private func checkFirstLaunch() {
        let hasLaunchedKey = "has_launched_before"
        isFirstLaunch = !UserDefaults.standard.bool(forKey: hasLaunchedKey)
        
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
        }
    }
    
    /**
     * Load theme preference from UserDefaults
     */
    private func loadThemePreference() {
        if let themeRawValue = UserDefaults.standard.string(forKey: "app_theme"),
           let theme = AppTheme(rawValue: themeRawValue) {
            currentTheme = theme
        }
    }
    
    // MARK: - Public Methods
    
    /**
     * Update the app theme preference
     */
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "app_theme")
        
        // Apply theme immediately
        applyThemeToWindows(theme)
    }
    
    /**
     * Apply theme to all app windows
     */
    private func applyThemeToWindows(_ theme: AppTheme) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        
        for window in windowScene.windows {
            switch theme {
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            case .automatic:
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
}
