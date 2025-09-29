import SwiftUI

class SettingsViewModel: BaseViewModel {
    @Published var scheme: String = "http"
    @Published var host: String = ""
    @Published var port: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var connectionStatus: String = ""
    @Published var libraries: [Library] = []
    @Published var selectedLibraryId: String?
    @Published var showLoginButton: Bool = false
    @Published var isLoggedIn: Bool = false
    
    private var apiClient: AudiobookshelfAPI?
    private let authService = AuthenticationService()
    private let keychainService = KeychainService.shared
    
    override init() {
        super.init()
        loadSavedSettings()
    }
    
    var statusColor: Color {
        if connectionStatus.contains("erfolgreich") {
            return .green
        } else if connectionStatus.contains("gefunden") {
            return .orange
        } else {
            return .red
        }
    }
    
    func autoTestConnection() {
        guard !host.isEmpty else { return }
        
        isLoading = true
        connectionStatus = ""
        showLoginButton = false
        
        let baseURL = "\(scheme)://\(host)\(port.isEmpty ? "" : ":\(port)")"
        
        Task {
            do {
                // Simple connectivity check
                guard let url = URL(string: "\(baseURL)/ping") else {
                    await MainActor.run {
                        self.connectionStatus = "Ungültige URL"
                        self.isLoading = false
                    }
                    return
                }
                AppLogger.debug.debug("Debug: connectionStatus = \(self.connectionStatus)")

                let (_, response) = try await URLSession.shared.data(from: url)
                
                await MainActor.run {
                    self.isLoading = false
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        switch httpResponse.statusCode {
                        case 200:
                            self.connectionStatus = "Server gefunden - Anmeldung erforderlich"
                            self.showLoginButton = !self.username.isEmpty && !self.password.isEmpty
                        default:
                            self.connectionStatus = "Server gefunden - Anmeldung erforderlich"
                            self.showLoginButton = !self.username.isEmpty && !self.password.isEmpty
}
                    } else {
                        self.connectionStatus = "Verbindung fehlgeschlagen"
                        self.showLoginButton = false
                    }
                    AppLogger.debug.debug("Debug: connectionStatus = \(self.connectionStatus)")

                }
            } catch {
                await MainActor.run {
                    self.connectionStatus = "Verbindung fehlgeschlagen: \(error.localizedDescription)"
                    self.isLoading = false
                    self.showLoginButton = false
                }
            }
        }
    }
    
    func login() {
        guard !host.isEmpty, !username.isEmpty, !password.isEmpty else { return }
        
        isLoading = true
        showLoginButton = false
        
        let baseURL = "\(scheme)://\(host)\(port.isEmpty ? "" : ":\(port)")"
        
        Task {
            do {
                let token = try await authService.login(
                    baseURL: baseURL,
                    username: username,
                    password: password
                )
                
                await MainActor.run {
                    self.isLoading = false
                    self.connectionStatus = "Anmeldung erfolgreich"
                    self.isLoggedIn = true
                    
                    // Store credentials securely
                    self.storeCredentials(baseURL: baseURL, token: token)
                    
                    // Create API client with token
                    self.apiClient = AudiobookshelfAPI(baseURL: baseURL, apiKey: token)
                    
                    // Fetch libraries
                    self.fetchLibrariesAndSave()
                }
            } catch {
                await MainActor.run {
                    self.connectionStatus = "Anmeldung fehlgeschlagen: \(error.localizedDescription)"
                    self.isLoading = false
                    self.showLoginButton = true
                    self.isLoggedIn = false
                }
            }
        }
    }
    
    func logout() {
        // Clear keychain
        do {
            try keychainService.clearAllCredentials()
        } catch {
            AppLogger.debug.debug("Failed to clear keychain: \(error)")
        }
        
        // Clear all state
        apiClient = nil
        libraries = []
        selectedLibraryId = nil
        connectionStatus = ""
        showLoginButton = false
        isLoggedIn = false
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "server_scheme")
        UserDefaults.standard.removeObject(forKey: "server_host")
        UserDefaults.standard.removeObject(forKey: "server_port")
        UserDefaults.standard.removeObject(forKey: "stored_username")
        UserDefaults.standard.removeObject(forKey: "baseURL")
        UserDefaults.standard.removeObject(forKey: "apiKey") // Legacy cleanup
        UserDefaults.standard.removeObject(forKey: "selected_library_id")
        
        // Clear form fields (except server settings)
        username = ""
        password = ""
        
        // Notify other views about logout
        NotificationCenter.default.post(name: .init("ServerSettingsChanged"), object: nil)
    }
    
    func onCredentialsChanged() {
        showLoginButton = !connectionStatus.isEmpty && !username.isEmpty && !password.isEmpty && !isLoggedIn
        AppLogger.debug.debug("Debug: showLoginButton = \(self.showLoginButton.description)")
        libraries = []
        selectedLibraryId = nil
        isLoggedIn = false
    }
    
    func saveSelectedLibrary(_ libraryId: String?) {
        if let id = libraryId {
            LibraryHelpers.saveLibrarySelection(id)
        } else {
            LibraryHelpers.saveLibrarySelection(nil)
        }
    }
    
    // MARK: - Private Methods
    
    private func storeCredentials(baseURL: String, token: String) {
        do {
            // Store password in keychain
            try keychainService.storePassword(password, for: username)
            
            // Store token in keychain
            try keychainService.storeToken(token, for: username)
            
            // Store non-sensitive data in UserDefaults
            UserDefaults.standard.set(scheme, forKey: "server_scheme")
            UserDefaults.standard.set(host, forKey: "server_host")
            UserDefaults.standard.set(port, forKey: "server_port")
            UserDefaults.standard.set(username, forKey: "stored_username")
            UserDefaults.standard.set(baseURL, forKey: "baseURL")
            
            // Notify other views about successful login
            NotificationCenter.default.post(name: .init("ServerSettingsChanged"), object: nil)
            
        } catch {
            AppLogger.debug.debug("Failed to store credentials: \(error)")
            connectionStatus = "Fehler beim Speichern der Anmeldedaten"
        }
    }
    
    private func fetchLibrariesAndSave() {
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
    
    private func loadSavedSettings() {
        // Load server settings
        scheme = UserDefaults.standard.string(forKey: "server_scheme") ?? "http"
        host = UserDefaults.standard.string(forKey: "server_host") ?? ""
        port = UserDefaults.standard.string(forKey: "server_port") ?? ""
        
        // Load username
        if let savedUsername = UserDefaults.standard.string(forKey: "stored_username") {
            username = savedUsername
            
            // Try to load password and token from keychain
            do {
                password = try keychainService.getPassword(for: savedUsername)
                let token = try keychainService.getToken(for: savedUsername)
                
                // Validate token
                if let baseURL = UserDefaults.standard.string(forKey: "baseURL") {
                    Task {
                        do {
                            let isValid = try await authService.validateToken(baseURL: baseURL, token: token)
                            await MainActor.run {
                                if isValid {
                                    self.isLoggedIn = true
                                    self.connectionStatus = "Bereits angemeldet"
                                    self.apiClient = AudiobookshelfAPI(baseURL: baseURL, apiKey: token)
                                    self.loadLibraries()
                                } else {
                                    // Token expired, require re-login
                                    self.connectionStatus = "Token abgelaufen - erneute Anmeldung erforderlich"
                                    self.showLoginButton = true
                                }
                            }
                        } catch {
                            await MainActor.run {
                                self.connectionStatus = "Token-Validierung fehlgeschlagen"
                                self.showLoginButton = true
                            }
                        }
                    }
                }
            } catch {
                // Password or token not found in keychain
                connectionStatus = "Anmeldedaten nicht verfügbar"
                showLoginButton = true
            }
        }
    }
    
    private func restoreSelectedLibrary() {
        if let savedId = UserDefaults.standard.string(forKey: "selected_library_id"),
           libraries.contains(where: { $0.id == savedId }) {
            selectedLibraryId = savedId
        } else if let defaultLibrary = libraries.first(where: { $0.name.lowercased().contains("default") }) {
            selectedLibraryId = defaultLibrary.id
            saveSelectedLibrary(defaultLibrary.id)
        } else if let firstLibrary = libraries.first {
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
