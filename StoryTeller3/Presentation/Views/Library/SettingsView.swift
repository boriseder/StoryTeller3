import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject var appConfig: AppConfig

    var body: some View {
        NavigationStack {
            Form {
                
                themeSection
                
                serverSection
                
                if viewModel.isServerConfigured {
                    connectionSection
                }
                
                credentialsSection  // Always show (handles both states internally)
                
                if viewModel.isLoggedIn {
                    librariesSection  // Only show when logged in
                }
                
                storageSection
                aboutSection
                advancedSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            
            .task {
                await viewModel.calculateStorageInfo()
            }
            .refreshable {
                await viewModel.calculateStorageInfo()
            }
            .alert("Clear All Cache?", isPresented: $viewModel.showingClearCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear \(viewModel.totalCacheSize)", role: .destructive) {
                    Task { await viewModel.clearAllCache() }
                }
            } message: {
                Text("This will clear all cached data including cover images and metadata. Downloaded books are not affected.")
            }
            .alert("Delete All Downloads?", isPresented: $viewModel.showingClearDownloadsAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    Task { await viewModel.clearAllDownloads() }
                }
            } message: {
                Text("This will permanently delete all \(viewModel.downloadedBooksCount) downloaded books. You can re-download them anytime when online.")
            }
            .alert("Logout?", isPresented: $viewModel.showingLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Logout", role: .destructive) {
                    viewModel.logout()
                }
            } message: {
                Text("You will need to enter your credentials again to reconnect.")
            }
            .alert("Connection Test", isPresented: $viewModel.showingTestResults) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.testResultMessage)
            }
        }
    }
    
    private var themeSection: some View {
        Section {
            // Background Style
            Picker("Background Style", selection: $appConfig.userBackgroundStyle) {
                Text("Dynamic").tag(UserBackgroundStyle.dynamic)
                Text("Light").tag(UserBackgroundStyle.light)
                Text("Dark").tag(UserBackgroundStyle.dark)
            }
            .pickerStyle(.menu)
            
            // Accent Color
            HStack {
                Text("Accent Color")
                Spacer()
                Menu {
                    Button(action: { appConfig.userAccentColor = .red }) {
                        Label("Red", systemImage: "circle.fill")
                    }
                    Button(action: { appConfig.userAccentColor = .orange }) {
                        Label("Orange", systemImage: "circle.fill")
                    }
                    Button(action: { appConfig.userAccentColor = .green }) {
                        Label("Green", systemImage: "circle.fill")
                    }
                    Button(action: { appConfig.userAccentColor = .blue }) {
                        Label("Blue", systemImage: "circle.fill")
                    }
                    Button(action: { appConfig.userAccentColor = .purple }) {
                        Label("Purple", systemImage: "circle.fill")
                    }
                    Button(action: { appConfig.userAccentColor = .pink }) {
                        Label("Pink", systemImage: "circle.fill")
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(appConfig.userAccentColor.color)
                        Text(appConfig.userAccentColor.rawValue.capitalized)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Label("Appearance", systemImage: "paintbrush")
        }
    }
    // MARK: - Server Section
    
    private var serverSection: some View {
        Section {
            Picker("Protocol", selection: $viewModel.scheme) {
                Text("http").tag("http")
                Text("https").tag("https")
            }
            .disabled(viewModel.isLoggedIn)
            
            TextField("Host", text: $viewModel.host)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.URL)
                .disabled(viewModel.isLoggedIn)
                .onChange(of: viewModel.host) { _, _ in
                    viewModel.sanitizeHost()
                }
            
            TextField("Port", text: $viewModel.port)
                .keyboardType(.numberPad)
                .disabled(viewModel.isLoggedIn)
            
            if viewModel.isServerConfigured {
                HStack {
                    Text("Server URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.fullServerURL)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        } header: {
            Label("Audiobookshelf Server", systemImage: "server.rack")
        } footer: {
            if viewModel.scheme == "http" {
                Label("HTTP is not secure. Use HTTPS when possible.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                Text("Enter the address of your Audiobookshelf server")
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Connection Section
    
    private var connectionSection: some View {
        Section {
            if viewModel.isTestingConnection {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Testing connection...")
                        .foregroundColor(.secondary)
                }
            } else if viewModel.connectionState != .initial {
                HStack {
                    Text(viewModel.connectionState.statusText)
                        .foregroundColor(viewModel.connectionState.statusColor)
                    Spacer()
                    if viewModel.connectionState == .authenticated {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if case .failed = viewModel.connectionState {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            
            if !viewModel.isLoggedIn {
                Button("Test Connection") {
                    viewModel.testConnection()
                }
                .disabled(!viewModel.canTestConnection)
            }
        } header: {
            Label("Connection Status", systemImage: "wifi")
        }
    }
    
    // MARK: - Credentials Section

    private var credentialsSection: some View {
        Section {
            if viewModel.isLoggedIn {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Logged in as")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.username)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                
                Button("Logout") {
                    viewModel.showingLogoutAlert = true
                }
                .foregroundColor(.red)
            } else {
                TextField("Username", text: $viewModel.username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                SecureField("Password", text: $viewModel.password)
                
                Button("Login") {
                    viewModel.login()
                }
                .disabled(!viewModel.canLogin)
                
                // ✅ NEW: Show loading state after login
                if viewModel.isTestingConnection {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Logging in and setting up...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Label("Authentication", systemImage: "person.badge.key")
        } footer: {
            if !viewModel.isLoggedIn && !viewModel.isTestingConnection {
                Text("Enter your Audiobookshelf credentials to connect")
                    .font(.caption)
            } else if viewModel.isTestingConnection {
                Text("Please wait while we validate your credentials and load your libraries")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    // MARK: - Libraries Section
    
    private var librariesSection: some View {
        Section {
            if viewModel.libraries.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading libraries...")
                        .foregroundColor(.secondary)
                }
            } else {
                Picker("Active Library", selection: $viewModel.selectedLibraryId) {
                    Text("No selection").tag(nil as String?)
                    ForEach(viewModel.libraries, id: \.id) { library in
                        HStack {
                            Text(library.name)
                            Spacer()
                            if library.id == viewModel.selectedLibraryId {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .tag(library.id as String?)
                    }
                }
                .onChange(of: viewModel.selectedLibraryId) { _, newId in
                    viewModel.saveSelectedLibrary(newId)
                }
                
                HStack {
                    Text("Total Libraries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(viewModel.libraries.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Label("Libraries", systemImage: "books.vertical")
        } footer: {
            Text("Select which library to use for browsing and playback")
                .font(.caption)
        }
    }
    
    // MARK: - Storage Section
    
    private var storageSection: some View {
        Section {
            if viewModel.isCalculatingStorage {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Calculating storage...")
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cache")
                            .font(.subheadline)
                        Text("Temporary files and cover images")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(viewModel.totalCacheSize)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                
                if viewModel.cacheOperationInProgress {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Clearing cache...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button("Clear All Cache") {
                        viewModel.showingClearCacheAlert = true
                    }
                    .foregroundColor(.orange)
                    
                    if let lastCleanup = viewModel.lastCacheCleanupDate {
                        HStack {
                            Text("Last cleared")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(lastCleanup, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Downloads")
                            .font(.subheadline)
                        Text("\(viewModel.downloadedBooksCount) books available offline")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(viewModel.totalDownloadSize)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                
                if viewModel.downloadedBooksCount > 0 {
                    Button("Delete All Downloads") {
                        viewModel.showingClearDownloadsAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
        } header: {
            Label("Storage & Downloads", systemImage: "internaldrive")
        } footer: {
            Text("Cache contains temporary files and can be safely cleared. Downloaded books are stored separately.")
                .font(.caption)
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section {
            HStack {
                Text("App Version")
                Spacer()
                Text(getAppVersion())
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text(getBuildNumber())
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            Link(destination: URL(string: "https://github.com/yourusername/storyteller")!) {
                HStack {
                    Text("GitHub Repository")
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Link(destination: URL(string: "https://www.audiobookshelf.org")!) {
                HStack {
                    Text("Audiobookshelf Project")
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Label("About", systemImage: "info.circle")
        }
    }
    
    // MARK: - Advanced Section
    
    private var advancedSection: some View {
        Section {
            NavigationLink(destination: AdvancedSettingsView(viewModel: viewModel)) {
                Label("Advanced Settings", systemImage: "gearshape.2")
            }
        } footer: {
            Text("Network settings, cache configuration, and debug options")
                .font(.caption)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getBuildNumber() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}
