import SwiftUI

struct SettingsView: View {
    
    // MARK: - State
    @State private var scheme: String = "http"
    @State private var host: String = ""
    @State private var port: String = ""
    @State private var apiKey: String = ""
    
    @State private var apiClient: AudiobookshelfAPI?
    @State private var libraries: [Library] = []
    @State private var selectedLibraryId: String?
    
    @State private var connectionStatus: String = ""
    @State private var isLoading: Bool = false
    @State private var showLoginButton: Bool = false
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Server")) {
                    Picker("Scheme", selection: $scheme) {
                        Text("http").tag("http")
                        Text("https").tag("https")
                    }
                    TextField("Host", text: $host)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }
                .onChange(of: host) { autoTestConnection() }
                .onChange(of: port) { autoTestConnection() }
                .onChange(of: scheme) { autoTestConnection() }

                Section(header: Text("API Key")) {
                    SecureField("API Key", text: $apiKey)
                        .onChange(of: apiKey) { _, newValue in
                            // Reset login state when API key changes
                            showLoginButton = !connectionStatus.isEmpty && !newValue.isEmpty
                            libraries = []
                            selectedLibraryId = nil
                        }
                }
                
                Section {
                    if isLoading {
                        HStack {
                            ProgressView().scaleEffect(0.8)
                            Text("Verbindung wird getestet...")
                        }
                    } else if !connectionStatus.isEmpty {
                        HStack {
                            Text(connectionStatus)
                                .foregroundColor(getStatusColor())
                            Spacer()
                            Button {
                                autoTestConnection()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        // Login Button only when server found and API key entered
                        if showLoginButton {
                            Button(action: {
                                login()
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
                        }
                    }
                }

                if !libraries.isEmpty {
                    Section(header: Text("Bibliotheken")) {
                        Picker("Bibliothek", selection: $selectedLibraryId) {
                            Text("Keine Auswahl").tag(nil as String?)
                            ForEach(libraries, id: \.id) { library in
                                Text(library.name).tag(library.id as String?)
                            }
                        }
                        .onChange(of: selectedLibraryId) { _, newId in
                            saveSelectedLibrary(newId)
                        }

                        // Logout Button
                        Button(action: logout) {
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
                }
                
                // Advanced Settings Link
                Section {
                    NavigationLink(destination: AdvancedSettingsView()) {
                        HStack {
                            Image(systemName: "gearshape.2")
                                .foregroundColor(.accentColor)
                            Text("Erweiterte Einstellungen")
                        }
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .onAppear {
                loadSavedSettings()
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getStatusColor() -> Color {
        if connectionStatus.contains("erfolgreich") {
            return .green
        } else if connectionStatus.contains("gefunden") {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Auto Connection Test
    private func autoTestConnection() {
        guard !host.isEmpty else { return }
        
        isLoading = true
        connectionStatus = ""
        showLoginButton = false
        
        let baseURL = "\(scheme)://\(host)\(port.isEmpty ? "" : ":\(port)")"
        let client = AudiobookshelfAPI(baseURL: baseURL, apiKey: apiKey.isEmpty ? "dummy" : apiKey)
        self.apiClient = client
        
        print("Testing connection with:")
        print("Base URL: \(baseURL)")
        print("Host: \(host)")
        print("Port: \(port)")
        print("Scheme: \(scheme)")
        
        Task {
            do {
                let result = try await client.testConnection()
                await MainActor.run {
                    self.isLoading = false
                    
                    switch result {
                    case .success:
                        if apiKey.isEmpty {
                            self.connectionStatus = "Server gefunden - API-Key eingeben"
                            self.showLoginButton = false
                        } else {
                            self.connectionStatus = "Verbindung erfolgreich"
                            self.showLoginButton = false
                            // Auto-login when connection is successful
                            self.fetchLibrariesAndSave()
                        }
                    case .serverFoundButUnauthorized:
                        self.connectionStatus = "Server gefunden - API-Key prüfen"
                        self.showLoginButton = !apiKey.isEmpty
                    case .failed:
                        self.connectionStatus = "Verbindung fehlgeschlagen"
                        self.showLoginButton = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.connectionStatus = "Verbindungsfehler: \(error.localizedDescription)"
                    self.isLoading = false
                    self.showLoginButton = false
                    print("Error details: \(error)")
                }
            }
        }
    }
    
    // MARK: - Login Action
    private func login() {
        guard !host.isEmpty, !apiKey.isEmpty else { return }
        
        isLoading = true
        showLoginButton = false
        
        let baseURL = "\(scheme)://\(host)\(port.isEmpty ? "" : ":\(port)")"
        let client = AudiobookshelfAPI(baseURL: baseURL, apiKey: apiKey)
        self.apiClient = client
        
        Task {
            do {
                let result = try await client.testConnection()
                await MainActor.run {
                    self.isLoading = false
                    
                    switch result {
                    case .success:
                        self.connectionStatus = "Anmeldung erfolgreich"
                        self.fetchLibrariesAndSave()
                    case .serverFoundButUnauthorized:
                        self.connectionStatus = "Anmeldung fehlgeschlagen - API-Key ungültig"
                        self.showLoginButton = true
                    case .failed:
                        self.connectionStatus = "Anmeldung fehlgeschlagen"
                        self.showLoginButton = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.connectionStatus = "Anmeldung fehlgeschlagen: \(error.localizedDescription)"
                    self.isLoading = false
                    self.showLoginButton = true
                }
            }
        }
    }
    
    // MARK: - Fetch Libraries and Save
    private func fetchLibrariesAndSave() {
        guard let client = apiClient else { return }
        
        Task {
            do {
                let libs = try await client.fetchLibraries()
                await MainActor.run {
                    self.libraries = libs
                    
                    // Save settings after successful login
                    let baseURL = "\(scheme)://\(host)\(port.isEmpty ? "" : ":\(port)")"
                    self.saveServerSettings(baseURL: baseURL, apiKey: apiKey)
                    
                    // Trigger UI refresh by posting notification
                    NotificationCenter.default.post(name: .init("ServerSettingsChanged"), object: nil)
                    
                    // Select default library
                    self.restoreSelectedLibrary()
                }
            } catch {
                await MainActor.run {
                    self.connectionStatus = "Bibliotheken konnten nicht geladen werden"
                    print("Error loading libraries: \(error)")
                }
            }
        }
    }
    
    // MARK: - Logout Action
    private func logout() {
        // Clear all state
        apiClient = nil
        libraries = []
        selectedLibraryId = nil
        connectionStatus = ""
        showLoginButton = false
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "server_scheme")
        UserDefaults.standard.removeObject(forKey: "server_host")
        UserDefaults.standard.removeObject(forKey: "server_port")
        UserDefaults.standard.removeObject(forKey: "baseURL")
        UserDefaults.standard.removeObject(forKey: "apiKey")
        UserDefaults.standard.removeObject(forKey: "selected_library_id")
        
        // Clear form fields
        scheme = "http"
        host = ""
        port = ""
        apiKey = ""
        
        // Notify other views about logout
        NotificationCenter.default.post(name: .init("ServerSettingsChanged"), object: nil)
        
        print("Abgemeldet - alle Daten gelöscht")
    }
    
    // MARK: - Persistence
    private func saveServerSettings(baseURL: String, apiKey: String) {
        UserDefaults.standard.set(scheme, forKey: "server_scheme")
        UserDefaults.standard.set(host, forKey: "server_host")
        UserDefaults.standard.set(port, forKey: "server_port")
        UserDefaults.standard.set(baseURL, forKey: "baseURL")
        UserDefaults.standard.set(apiKey, forKey: "apiKey")
        
        // Notify other views to reload
        NotificationCenter.default.post(name: .init("ServerSettingsChanged"), object: nil)
    }
    
    private func saveSelectedLibrary(_ libraryId: String?) {
        if let id = libraryId {
            UserDefaults.standard.set(id, forKey: "selected_library_id")
        } else {
            UserDefaults.standard.removeObject(forKey: "selected_library_id")
        }
    }
    
    private func loadSavedSettings() {
        scheme = UserDefaults.standard.string(forKey: "server_scheme") ?? "http"
        host = UserDefaults.standard.string(forKey: "server_host") ?? ""
        port = UserDefaults.standard.string(forKey: "server_port") ?? ""
        apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        
        if let baseURL = UserDefaults.standard.string(forKey: "baseURL"),
           !host.isEmpty, !apiKey.isEmpty {
            apiClient = AudiobookshelfAPI(baseURL: baseURL, apiKey: apiKey)
            loadLibraries()
        }
    }
    
    private func restoreSelectedLibrary() {
        if let savedId = UserDefaults.standard.string(forKey: "selected_library_id"),
           libraries.contains(where: { $0.id == savedId }) {
            selectedLibraryId = savedId
        } else if let defaultLibrary = libraries.first(where: { $0.name.lowercased().contains("default") }) {
            // Try to find a default library
            selectedLibraryId = defaultLibrary.id
            saveSelectedLibrary(defaultLibrary.id)
        } else if let firstLibrary = libraries.first {
            // Fallback to first library
            selectedLibraryId = firstLibrary.id
            saveSelectedLibrary(firstLibrary.id)
        }
    }
    
    private func loadLibraries() {
        guard let client = apiClient else { return }
        Task {
            do {
                let libs = try await client.fetchLibraries()
                await MainActor.run {
                    self.libraries = libs
                    self.restoreSelectedLibrary()
                }
            } catch {
                await MainActor.run {
                    self.connectionStatus = "Bibliotheken konnten nicht geladen werden"
                }
            }
        }
    }
}
