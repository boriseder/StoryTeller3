import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                credentialsSection
                connectionSection
                
                if !viewModel.libraries.isEmpty {
                    librariesSection
                }
                
                cacheSection
                coverCacheSection
                downloadSection
                networkSection
                aboutSection
                debugSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { viewModel.loadSettings() }
            .refreshable { await viewModel.calculateStorageInfo() }
            .alert("Empty App-Cache", isPresented: $viewModel.showingClearAppCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { Task { await viewModel.clearAppCache() } }
            }
            .alert("Kompletten Cache leeren", isPresented: $viewModel.showingClearAllCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Alles Delete", role: .destructive) { Task { await viewModel.clearCompleteCache() } }
            }
            .alert("Downloads Delete", isPresented: $viewModel.showingClearDownloadsAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Alle Delete", role: .destructive) { Task { await viewModel.clearAllDownloads() } }
            }
            .alert("Cover-Cache verwalten", isPresented: $viewModel.showingClearCoverCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Nur Memory", role: .destructive) { viewModel.clearCoverMemoryCache() }
                Button("Alles Delete", role: .destructive) { viewModel.coverCacheManager.clearAllCache() }
            }

        }
    }
    
    // MARK: - Server Section
    private var serverSection: some View {
        Section(header: Text("Audiobookshelf Server")) {
            Picker("Scheme", selection: $viewModel.scheme) {
                Text("http").tag("http")
                Text("https").tag("https")
            }
            .disabled(viewModel.isLoggedIn)
            if viewModel.scheme == "http" {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("HTTP is not secure. Use HTTPS when possible.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
            }
            
            TextField("Host", text: $viewModel.host)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .disabled(viewModel.isLoggedIn)
            
            TextField("Port", text: $viewModel.port)
                .keyboardType(.numberPad)
                .disabled(viewModel.isLoggedIn)
        }
        .onChange(of: viewModel.host) { _, _ in
            if !viewModel.isLoggedIn {
                viewModel.autoTestConnection()
            }
        }
        .onChange(of: viewModel.port) { _, _ in
            if !viewModel.isLoggedIn {
                viewModel.autoTestConnection()
            }
        }
        .onChange(of: viewModel.scheme) { _, _ in
            if !viewModel.isLoggedIn {
                viewModel.autoTestConnection()
            }
        }
    }
    
    // MARK: - Credentials Section
    private var credentialsSection: some View {
        Section(header: Text("Authentication")) {
            TextField("Username", text: $viewModel.username)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .disabled(viewModel.isLoggedIn)
                .onChange(of: viewModel.username) { _, _ in
                    viewModel.onCredentialsChanged()
                }
            
            SecureField("Password", text: $viewModel.password)
                .disabled(viewModel.isLoggedIn)
                .onChange(of: viewModel.password) { _, _ in
                    viewModel.onCredentialsChanged()
                    AppLogger.debug.debug("Debug: showLoginButton = \(viewModel.showLoginButton)")
               }
        }
    }
    
    // MARK: - Connection Section
    private var connectionSection: some View {
        Section {
            if viewModel.isLoading {
                connectionLoadingView
                let _ = AppLogger.debug.debug("Debug: showLoginButton = \(viewModel.showLoginButton)")

            } else if !viewModel.connectionStatus.isEmpty {
                connectionStatusView
                let _ = AppLogger.debug.debug("Debug: connectionStatus = \(viewModel.connectionStatus)")

                if viewModel.showLoginButton {
                    let _ = AppLogger.debug.debug("Debug: showLoginButton = \(viewModel.showLoginButton)")

                    loginButton
                } else if viewModel.isLoggedIn {
                    let _ = AppLogger.debug.debug("Debug: showLoginButton = \(viewModel.showLoginButton)")

                    loggedInView
                }
            }
        }
    }
    
    private var connectionLoadingView: some View {
        HStack {
            ProgressView().scaleEffect(0.8)
            Text("Testing connection...")
        }
    }
    
    private var connectionStatusView: some View {
        HStack {
            Text(viewModel.connectionStatus)
                .foregroundColor(viewModel.statusColor)
            Spacer()
            if !viewModel.isLoggedIn {
                Button {
                    viewModel.autoTestConnection()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
        }
    }
    
    private var loginButton: some View {
        Button(action: {
            viewModel.login()
        }) {
            HStack {
                Image(systemName: "person.badge.key")
                Text("Login")
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.username.isEmpty || viewModel.password.isEmpty)
    }
    
    private var loggedInView: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Login as \(viewModel.username)")
                .foregroundColor(.primary)
            Spacer()
        }
    }
    
    // MARK: - Libraries Section
    private var librariesSection: some View {
        Section(header: Text("Libraries")) {
            Picker("Library", selection: $viewModel.selectedLibraryId) {
                Text("No selection").tag(nil as String?)
                ForEach(viewModel.libraries, id: \.id) { library in
                    Text(library.name).tag(library.id as String?)
                }
            }
            .onChange(of: viewModel.selectedLibraryId) { _, newId in
                viewModel.saveSelectedLibrary(newId)
            }
            
            if viewModel.isLoggedIn {
                logoutButton
            }
        }
    }
    
    private var logoutButton: some View {
        Button(action: {
            viewModel.logout()
        }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Logout")
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Advanced Settings Section

    private var cacheSection: some View {
        Section {
            HStack { Text("App-Cache"); Spacer(); Text(viewModel.appCacheSize).foregroundColor(.secondary) }
            Button("Empty App-Cache") { viewModel.showingClearAppCacheAlert = true }.foregroundColor(.orange)
            Button("Empty all cached data") { viewModel.showingClearAllCacheAlert = true }.foregroundColor(.red)
        } header: {
            Label("Manage Cache", systemImage: "externaldrive.fill")
        }
    }

    private var coverCacheSection: some View {
        Section {
            HStack { Text("Cover-Cache"); Spacer(); Text(viewModel.coverCacheSize).foregroundColor(.secondary) }
            Stepper("Memory Cache Limit: \(viewModel.coverCacheLimit)", value: $viewModel.coverCacheLimit, in: 50...200, step: 10) {_ in
                viewModel.saveCoverCacheSettings()
            }
            Stepper("Memory Size: \(viewModel.memoryCacheSize) MB", value: $viewModel.memoryCacheSize, in: 25...200, step: 5) {_ in
                viewModel.saveCoverCacheSettings()
            }
            Button("Manage Cover-Cache") { viewModel.showingClearCoverCacheAlert = true }.foregroundColor(.blue)
        } header: {
            Label("Cover-Cache", systemImage: "photo.stack.fill")
        }
    }

    private var downloadSection: some View {
        Section {
            HStack { Text("Downloaded booksr"); Spacer(); Text("\(viewModel.downloadedBooksCount)").foregroundColor(.secondary) }
            Stepper("Max. concurrent downloads: \(viewModel.maxConcurrentDownloads)", value: $viewModel.maxConcurrentDownloads, in: 1...5) {_ in
                viewModel.saveDownloadSettings()
            }
            Button("Delete all downloads") { viewModel.showingClearDownloadsAlert = true }.foregroundColor(.red).disabled(viewModel.downloadedBooksCount == 0)
        } header: {
            Label("Download settings", systemImage: "arrow.down.circle.fill")
        }
    }

    private var networkSection: some View {
        Section {
            VStack(alignment: .leading) {
                Text("Connection timeout: \(Int(viewModel.connectionTimeout))s")
                Slider(value: $viewModel.connectionTimeout, in: 10...60, step: 5) { _ in viewModel.saveNetworkSettings() }
            }
        } header: {
            Label("Network settings", systemImage: "network")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("App Version")
                Spacer()
                Text(getAppVersion())
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text(getBuildNumber())
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("About")
        }
    }
    
    private var debugSection: some View {
        Section {
            Toggle("Debug-Protokollierung", isOn: $viewModel.enableDebugLogging).onChange(of: viewModel.enableDebugLogging) { viewModel.toggleDebugLogging($0) }
        } header: {
            Label("Debug-Einstellungen", systemImage: "ladybug.fill")
            
            Button("Trigger Critical Cleanup") {
                CoverCacheManager.shared.triggerCriticalCleanup()
            }
        }
    }
    
    private func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private func getBuildNumber() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

}

struct StorageItem: View {
    let title: String
    let size: String
    let color: Color
    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(title)
            Spacer()
            Text(size).foregroundColor(.secondary)
        }
    }
}

