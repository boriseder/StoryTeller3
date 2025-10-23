import SwiftUI
import Combine

struct ContentView: View {
    // MARK: - Environment
    @EnvironmentObject private var appState: AppStateManager
    @EnvironmentObject private var theme: ThemeManager

    // MARK: - State Objects
    @StateObject private var player = AudioPlayer()
    @StateObject private var downloadManager = DownloadManager()
    @StateObject private var playerStateManager = PlayerStateManager()

    // MARK: - State Variables
    @State private var selectedTab: TabIndex = .home
    @State private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Tab Enum
    enum TabIndex: Hashable {
        case home, library, series, downloads
    }
    
    var body: some View {
        ZStack {
            Color.accent.ignoresSafeArea()

            switch appState.loadingState {
            
            case .initial, .loadingCredentials, .credentialsFoundValidating:
                LoadingView(message: "Loading")
                    .padding(.top, 56)   // avoid jumping from contentView to homeView

            case .noCredentialsSaved:
                Color.clear
                    .onAppear {
                        if UserDefaults.standard.string(forKey: "stored_username") != nil {
                            Task {
                                setupApp()
                            }
                        } else if appState.isFirstLaunch {
                            appState.showingWelcome = true
                        } else {
                            appState.showingSettings = true
                        }
                    }
            
            case .networkError(let issueType):
                NetworkErrorView(
                    issueType: issueType,
                    downloadedBooksCount: downloadManager.downloadedBooks.count,
                    onRetry: {
                        Task {
                            setupApp()
                        }
                    },
                    onViewDownloads: {
                        selectedTab = .downloads
                        appState.loadingState = .ready
                    },
                    onSettings: {
                        appState.showingSettings = true
                    }
                )
                    
            case .authenticationError:
                AuthErrorView(
                    onReLogin: {
                        appState.showingSettings = true
                    }
                )
                    
            case .loadingData:
                LoadingView(message: "Loading")
                    .padding(.top, 56)   // avoid jumping from contentView to homeView

            case .ready:
                mainContent
            }
        }
        .onAppear(perform: setupApp)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            if UserDefaults.standard.bool(forKey: "auto_cache_cleanup") {
                Task {
                    await CoverCacheManager.shared.optimizeCache()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ServerSettingsChanged"))) { _ in
            appState.clearConnectionIssue()
            Task {
                setupApp()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ShowSettings"))) { _ in
            appState.showingSettings = true
        }
        .onChange(of: appState.isDeviceOnline) { oldValue, newValue in
            if !oldValue && newValue {
                Task {
                    await appState.checkServerReachability()
                    if appState.isServerReachable {
                        setupApp()
                    }
                }
            }
        }
        .onDisappear {
            cancellables.removeAll()
        }
        .sheet(isPresented: $appState.showingSettings) {
            NavigationStack {
                SettingsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                appState.showingSettings = false
                                Task {
                                    setupApp()
                                }
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $appState.showingWelcome) {
            WelcomeView {
                appState.showingWelcome = false
                appState.showingSettings = true
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Main Content
    private var mainContent: some View {
        FullscreenPlayerContainer(
            player: player,
            playerStateManager: playerStateManager,
            api: appState.apiClient
        ) {
            TabView(selection: $selectedTab) {
                homeTab
                libraryTab
                seriesTab
                downloadsTab
            }
            .accentColor(theme.accent)
            .id(theme.accent) // zwingt SwiftUI, die TabView neu zu rendern, wenn sich die Farbe ändert
        }
    }
    
    
    // MARK: - Tab Views
    
    private var homeTab: some View {
        NavigationStack {
            ZStack {
                if let api = appState.apiClient {
                    HomeView(
                        player: player,
                        api: api,
                        downloadManager: downloadManager,
                        onBookSelected: { openFullscreenPlayer() }
                    )
                    .environmentObject(appState)
                }
            }
        }
        .tabItem {
            Image(systemName: "sharedwithyou")
            Text("Explore")
        }
        .tag(TabIndex.home)
    }
    
    private var libraryTab: some View {
        NavigationStack {
            if let api = appState.apiClient {
                LibraryView(
                    player: player,
                    api: api,
                    downloadManager: downloadManager,
                    onBookSelected: { openFullscreenPlayer() }
                )
                .environmentObject(appState)
            }
        }
        .tabItem {
            Image(systemName: "books.vertical.fill")
            Text("Library")
        }
        .tag(TabIndex.library)
    }
    
    private var seriesTab: some View {
        NavigationStack {
            if let api = appState.apiClient {
                SeriesView(
                    player: player,
                    api: api,
                    downloadManager: downloadManager,
                    onBookSelected: { openFullscreenPlayer() }
                )
                .environmentObject(appState)
            }
        }
        .tabItem {
            Image(systemName: "play.square.stack.fill")
            Text("Series")
        }
        .tag(TabIndex.series)
    }
    
    private var downloadsTab: some View {
        NavigationStack {
            if let api = appState.apiClient {
                DownloadsView(
                    downloadManager: downloadManager,
                    player: player,
                    api: api,
                    appState: appState,
                    onBookSelected: { openFullscreenPlayer() }
                )
                .environmentObject(appState)
            } else {
                DownloadsView(
                    downloadManager: downloadManager,
                    player: player,
                    api: AudiobookshelfAPI(baseURL: "", apiKey: ""),
                    appState: appState,
                    onBookSelected: { openFullscreenPlayer() }
                )
                .environmentObject(appState)
            }
        }
        .tabItem {
            Image(systemName: "arrow.down.circle.fill")
            Text("Downloads")
        }
        .badge(downloadManager.downloadedBooks.count)
        .tag(TabIndex.downloads)
    }

    
    // MARK: - Helper Functions

    private func openFullscreenPlayer() {
        playerStateManager.showFullscreen()
    }
    
    
    // MARK: - Setup Methods
    
    private func setupApp() {
        Task { @MainActor in
            appState.loadingState = .loadingCredentials
            
            guard let baseURL = UserDefaults.standard.string(forKey: "baseURL"),
                  let username = UserDefaults.standard.string(forKey: "stored_username") else {
                appState.loadingState = .noCredentialsSaved
                return
            }
            
            appState.loadingState = .credentialsFoundValidating
            
            do {
                let token = try KeychainService.shared.getToken(for: username)
                let client = AudiobookshelfAPI(baseURL: baseURL, apiKey: token)
                
                let connectionResult = await testConnection(client: client)
                
                switch connectionResult {
                case .success:
                    appState.apiClient = client
                    player.configure(baseURL: baseURL, authToken: token, downloadManager: downloadManager)
                    
                    appState.loadingState = .loadingData
                    
                    // ✅ USE REPOSITORY instead of direct API call
                    await loadInitialData(client: client)
                    
                    appState.loadingState = .ready
                    appState.isServerReachable = true
                    
                case .networkError(let issueType):
                    appState.isServerReachable = false
                    appState.loadingState = .networkError(issueType)
                    
                case .authenticationError:
                    appState.loadingState = .authenticationError
                }
                
            } catch {
                AppLogger.general.error("[ContentView] Keychain error: \(error)")
                appState.loadingState = .authenticationError
            }
        }
    }
    
    // ✅ CORRECTED: Use Repository Pattern
    private func loadInitialData(client: AudiobookshelfAPI) async {
        AppLogger.general.debug("[ContentView] Loading initial data via Repository...")
        
        // Create repository instance
        let libraryRepository = LibraryRepository(
            api: client,
            settingsRepository: SettingsRepository()
        )
        
        do {
            // Let repository handle all the logic
            let selectedLibrary = try await libraryRepository.initializeLibrarySelection()
            
            if let library = selectedLibrary {
                AppLogger.general.info("[ContentView] ✓ Library initialized: \(library.name)")
            } else {
                AppLogger.general.warn("[ContentView] No libraries available (valid for new servers)")
            }
            
        } catch let error as RepositoryError {
            handleRepositoryError(error)
        } catch {
            AppLogger.general.error("[ContentView] Initial data load failed: \(error)")
        }
    }
    
    // Handle repository-specific errors
    private func handleRepositoryError(_ error: RepositoryError) {
        switch error {
        case .networkError(let urlError as URLError):
            switch urlError.code {
            case .notConnectedToInternet:
                AppLogger.general.error("[ContentView] No internet - offline mode available")
            case .timedOut:
                AppLogger.general.error("[ContentView] Timeout - server might be slow")
            default:
                AppLogger.general.error("[ContentView] Network error: \(urlError)")
            }
            
        case .decodingError:
            AppLogger.general.error("[ContentView] Data format error - check server version")
            
        case .unauthorized:
            appState.loadingState = .authenticationError
            
        default:
            AppLogger.general.error("[ContentView] Repository error: \(error)")
        }
    }

    
    // MARK: - Connection Testing
    
    enum ConnectionTestResult {
        case success
        case networkError(ConnectionIssueType)
        case authenticationError
    }
    
    private func testConnection(client: AudiobookshelfAPI) async -> ConnectionTestResult {
        guard appState.isDeviceOnline else {
            return .networkError(.noInternet)
        }
        
        let isHealthy = await client.checkConnectionHealth()
        
        guard isHealthy else {
            return .networkError(.serverUnreachable)
        }
        
        do {
            _ = try await client.fetchLibraries()
            return .success
        } catch AudiobookshelfError.unauthorized {
            return .authenticationError
        } catch AudiobookshelfError.serverError(let code, _) where code >= 500 {
            return .networkError(.serverError)
        } catch {
            return .networkError(.serverUnreachable)
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    let onComplete: () -> Void
    
    @State private var currentPage = 0
    private let totalPages = 3
    
    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    onComplete()
                }
                .foregroundColor(.white.opacity(0.8))
                .padding()
            }
            
            Spacer()
            
            // Page content
            TabView(selection: $currentPage) {
                WelcomePageView(
                    systemImage: "headphones.circle.fill",
                    title: "Welcome to StoryTeller",
                    description: "Your personal audiobook library, powered by Audiobookshelf"
                )
                .tag(0)
                
                WelcomePageView(
                    systemImage: "arrow.down.circle.fill",
                    title: "Download & Listen Offline",
                    description: "Download your favorite audiobooks and listen anywhere, anytime"
                )
                .tag(1)
                
                WelcomePageView(
                    systemImage: "server.rack",
                    title: "Connect Your Server",
                    description: "Connect to your Audiobookshelf server to get started"
                )
                .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            .padding(.bottom, 32)
            
            // Action button
            Button(action: {
                if currentPage < totalPages - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    onComplete()
                }
            }) {
                Text(currentPage == totalPages - 1 ? "Get Started" : "Next")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor,
                    Color.accentColor.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Welcome Page View
struct WelcomePageView: View {
    let systemImage: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: systemImage)
                .font(.system(size: 80))
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding()
    }
}
