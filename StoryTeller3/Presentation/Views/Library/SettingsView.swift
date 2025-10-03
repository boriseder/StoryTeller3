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
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { viewModel.loadSettings() }
            .refreshable { await viewModel.calculateStorageInfo() }
            .alert("App-Cache leeren", isPresented: $viewModel.showingClearAppCacheAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) { Task { await viewModel.clearAppCache() } }
            }
            .alert("Kompletten Cache leeren", isPresented: $viewModel.showingClearAllCacheAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Alles löschen", role: .destructive) { Task { await viewModel.clearCompleteCache() } }
            }
            .alert("Downloads löschen", isPresented: $viewModel.showingClearDownloadsAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Alle löschen", role: .destructive) { Task { await viewModel.clearAllDownloads() } }
            }
            .alert("Cover-Cache verwalten", isPresented: $viewModel.showingClearCoverCacheAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Nur Memory", role: .destructive) { viewModel.clearCoverMemoryCache() }
                Button("Alles löschen", role: .destructive) { viewModel.coverCacheManager.clearAllCache() }
            }

        }
    }
    
    // MARK: - Server Section
    private var serverSection: some View {
        Section(header: Text("Server")) {
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
        Section(header: Text("Anmeldedaten")) {
            TextField("Benutzername", text: $viewModel.username)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .disabled(viewModel.isLoggedIn)
                .onChange(of: viewModel.username) { _, _ in
                    viewModel.onCredentialsChanged()
                }
            
            SecureField("Passwort", text: $viewModel.password)
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
            Text("Verbindung wird getestet...")
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
                Text("Anmelden")
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
            Text("Angemeldet als \(viewModel.username)")
                .foregroundColor(.primary)
            Spacer()
        }
    }
    
    // MARK: - Libraries Section
    private var librariesSection: some View {
        Section(header: Text("Bibliotheken")) {
            Picker("Bibliothek", selection: $viewModel.selectedLibraryId) {
                Text("Keine Auswahl").tag(nil as String?)
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
                Text("Abmelden")
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
            Button("App-Cache leeren") { viewModel.showingClearAppCacheAlert = true }.foregroundColor(.orange)
            Button("Kompletten Cache leeren") { viewModel.showingClearAllCacheAlert = true }.foregroundColor(.red)
        } header: {
            Label("Cache-Verwaltung", systemImage: "externaldrive.fill")
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
            Button("Cover-Cache verwalten") { viewModel.showingClearCoverCacheAlert = true }.foregroundColor(.blue)
        } header: {
            Label("Cover-Cache", systemImage: "photo.stack.fill")
        }
    }

    private var downloadSection: some View {
        Section {
            HStack { Text("Heruntergeladene Bücher"); Spacer(); Text("\(viewModel.downloadedBooksCount)").foregroundColor(.secondary) }
            Stepper("Max. gleichzeitige Downloads: \(viewModel.maxConcurrentDownloads)", value: $viewModel.maxConcurrentDownloads, in: 1...5) {_ in
                viewModel.saveDownloadSettings()
            }
            Button("Alle Downloads löschen") { viewModel.showingClearDownloadsAlert = true }.foregroundColor(.red).disabled(viewModel.downloadedBooksCount == 0)
        } header: {
            Label("Download-Einstellungen", systemImage: "arrow.down.circle.fill")
        }
    }

    private var networkSection: some View {
        Section {
            VStack(alignment: .leading) {
                Text("Verbindungs-Timeout: \(Int(viewModel.connectionTimeout))s")
                Slider(value: $viewModel.connectionTimeout, in: 10...60, step: 5) { _ in viewModel.saveNetworkSettings() }
            }
        } header: {
            Label("Netzwerk-Einstellungen", systemImage: "network")
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

