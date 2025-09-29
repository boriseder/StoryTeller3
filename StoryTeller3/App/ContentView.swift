import SwiftUI
import Combine

struct ContentView: View {
    // MARK: - State Objects
    @StateObject private var player = AudioPlayer()
    @StateObject private var downloadManager = DownloadManager()
    @StateObject private var playerStateManager = PlayerStateManager()

    // MARK: - State Variables
    @State private var selectedTab: TabIndex = .home
    @State private var apiClient: AudiobookshelfAPI?
    @State private var appLoaded = false
    @State private var showingWelcome = false
    @State private var showingSettings = false
    
    @State private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Tab Enum (nur noch 2 Tabs)
    enum TabIndex: Hashable {
        case home, library, series, downloads
    }

    var body: some View {
                    
            FullscreenPlayerContainer(
                player: player,
                playerStateManager: playerStateManager,
                api: apiClient
            ) {
                TabView(selection: $selectedTab) {
                    
                    // MARK: - Home Tab
                    homeTabWithToolbar()
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Home")
                        }
                        .tag(TabIndex.home)
                    
                    // MARK: - Library Tab
                    libraryTabWithToolbar()
                        .tabItem {
                            Image(systemName: "books.vertical.fill")
                            Text("Bibliothek")
                        }
                        .tag(TabIndex.library)
                    
                    // MARK: - Series Tab
                    seriesTabWithToolbar()
                        .tabItem {
                            Image(systemName: "rectangle.stack.fill")
                            Text("Serien")
                        }
                        .tag(TabIndex.series)
                    
                    
                    // MARK: - Downloads Tab
                    downloadsTabWithToolbar()
                        .tabItem {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Downloads")
                        }
                        .badge(downloadManager.downloadedBooks.count)
                        .tag(TabIndex.downloads)
                }
                .tint(.accentColor)
            }
            .onAppear(
                perform: setupApp
            )
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                // Optimize cache when app goes to background
                if UserDefaults.standard.bool(forKey: "auto_cache_cleanup") {
                    Task {
                        await CoverCacheManager.shared.optimizeCache()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("ServerSettingsChanged"))) { _ in
                loadAPIClient()
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("ShowSettings"))) { _ in
                showingSettings = true
            }
            .onDisappear {
                cancellables.removeAll()
            }
            
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Fertig") {
                                    showingSettings = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingWelcome) {
                if showingWelcome {
                    WelcomeView {
                        showingWelcome = false
                        showingSettings = true
                    }
                    .background(Color.accentColor.ignoresSafeArea())
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showingWelcome)
                }
            }
    }
    
    // MARK: - Helper Views mit Toolbar
  
    
    @ViewBuilder
    private func homeTabWithToolbar() -> some View {
        NavigationStack {
            if let api = apiClient {
                HomeView(
                    player: player,
                    api: api,
                    downloadManager: downloadManager,
                    onBookSelected: { openFullscreenPlayer() }
                )
            }
        }
    }

    
    @ViewBuilder
    private func seriesTabWithToolbar() -> some View {
        NavigationStack {
            if let api = apiClient {
                SeriesView(
                    player: player,
                    api: api,
                    downloadManager: downloadManager,
                    onBookSelected: { openFullscreenPlayer() }
                )
            }
        }
    }
    
    @ViewBuilder
    private func libraryTabWithToolbar() -> some View {
        NavigationStack {
            if let api = apiClient {
                LibraryView(
                    player: player,
                    api: api,
                    downloadManager: downloadManager,
                    onBookSelected: { openFullscreenPlayer() }
                )
            }
        }
    }
    
    @ViewBuilder
    private func downloadsTabWithToolbar() -> some View {
        NavigationStack {
            DownloadsView(
                downloadManager: downloadManager,
                player: player,
                api: apiClient,
                onBookSelected: { openFullscreenPlayer() }
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    settingsButton
                }
            }
        }
    }
    
    // MARK: - Settings Button (Zahnrad-Symbol)
    private var settingsButton: some View {
        Button(action: {
            showingSettings = true
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18))
                .foregroundColor(.primary)
        }
    }

    // MARK: - Helper Functions

    private func openFullscreenPlayer() {
        playerStateManager.showFullscreen()
    }
    
    // MARK: - Setup Methods
    
    private func setupApp() {

        loadAPIClient()
        setupNotificationObservers()
 
        // App als geladen markieren, damit ZStack den Inhalt rendert
        DispatchQueue.main.async {
            self.appLoaded = true

            // Erst jetzt prüfen, ob WelcomeView gezeigt werden soll
            checkFirstLaunch()
        }

    }
    
    private func setupNotificationObservers() {
        // Background cache optimization
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { _ in
                if UserDefaults.standard.bool(forKey: "auto_cache_cleanup") {
                    Task {
                        await CoverCacheManager.shared.optimizeCache()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Server settings changed
        NotificationCenter.default.publisher(for: .init("ServerSettingsChanged"))
            .sink { _ in
                loadAPIClient()
            }
            .store(in: &cancellables)
    }
    
    // Add this method to ContentView.swift to replace loadAPIClient()

    private func loadAPIClient() {
        guard let baseURL = UserDefaults.standard.string(forKey: "baseURL"),
              let username = UserDefaults.standard.string(forKey: "stored_username") else {
            apiClient = nil
            return
        }
        
        do {
            let token = try KeychainService.shared.getToken(for: username)
            let client = AudiobookshelfAPI(baseURL: baseURL, apiKey: token)
            
            // Test connection health before setting as active client
            Task {
                let isHealthy = await client.checkConnectionHealth()
                await MainActor.run {
                    if isHealthy {
                        apiClient = client
                        player.configure(baseURL: baseURL, authToken: token, downloadManager: downloadManager)
                    } else {
                        AppLogger.debug.debug("API client health check failed")
                        // Keep apiClient nil to show NoServerConfiguredView
                        apiClient = nil
                    }
                }
            }
            
        } catch {
            AppLogger.debug.debug("Failed to load authentication token: \(error)")
            apiClient = nil
        }
    }
    
    private func checkFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "has_launched_before")
        if !hasLaunchedBefore {
            UserDefaults.standard.set(true, forKey: "has_launched_before")
            // Verzögert setzen, damit UI schon aufgebaut ist
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showingWelcome = true
            }
        }
    }
}

// MARK: - Updated NoServerConfiguredView mit Action Closure
struct NoServerConfiguredView: View {
    let onConfigureServer: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "server.rack")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
            }
            
            // Content
            VStack(spacing: 12) {
                Text("Willkommen bei StoryTeller")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("Verbinden Sie sich mit Ihrem Audiobookshelf-Server, um Ihre Hörbuch-Sammlung zu entdecken")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Action Button
            Button(action: onConfigureServer) {
                HStack {
                    Image(systemName: "gear")
                    Text("Server konfigurieren")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.accentColor)
                .clipShape(Capsule())
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarHidden(true)
    }
}

// Rest der Supporting Views bleiben unverändert...
// (WelcomeView, WelcomePageView, PrimaryButtonStyle, SecondaryButtonStyle)
// Rest der Supporting Views bleiben unverändert...
// (WelcomeView, WelcomePageView, PrimaryButtonStyle, SecondaryButtonStyle)
// Rest der Supporting Views bleiben unverändert...
// (WelcomeView, WelcomePageView, PrimaryButtonStyle, SecondaryButtonStyle)
// MARK: - Supporting Views

/// Enhanced tab item view with selection state and optional badge
struct TabItemView: View {
    let systemImage: String
    let title: String
    let isSelected: Bool
    let badge: String?
    
    init(systemImage: String, title: String, isSelected: Bool, badge: String? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.isSelected = isSelected
        self.badge = badge
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                
                // Badge overlay
                if let badge = badge {
                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 12, y: -8)
                }
            }
            
            Text(title)
                .font(.caption2)
        }
    }
}

/// Welcome screen for first-time users
struct WelcomeView: View {
    let onComplete: () -> Void
    
    @State private var currentPage = 0
    private let totalPages = 3
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Page Content
                Text("HALLOOOOOOO").font(DSText.pageTitle)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Page Indicator
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.bottom, 32)
                
                // Action Buttons
            }
            .navigationBarHidden(true)
        }
}

