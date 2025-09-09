import SwiftUI

class SettingsViewModel: BaseViewModel {
    @Published var scheme: String = "http"
    @Published var host: String = ""
    @Published var port: String = ""
    @Published var apiKey: String = ""
    @Published var connectionStatus: String = ""
    @Published var libraries: [Library] = []
    @Published var selectedLibraryId: String?
    @Published var showLoginButton: Bool = false
    
    private var apiClient: AudiobookshelfAPI?
    
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
        let client = AudiobookshelfAPI(baseURL: baseURL, apiKey: apiKey.isEmpty ? "dummy" : apiKey)
        self.apiClient = client
        
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
                }
            }
        }
    }
    
    func login() {
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
    
    func logout() {
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
    }
    
    func onApiKeyChanged(_ newValue: String) {
        // Reset login state when API key changes
        showLoginButton = !connectionStatus.isEmpty && !newValue.isEmpty
        libraries = []
        selectedLibraryId = nil
    }
    
    func saveSelectedLibrary(_ libraryId: String?) {
        if let id = libraryId {
            UserDefaults.standard.set(id, forKey: "selected_library_id")
        } else {
            UserDefaults.standard.removeObject(forKey: "selected_library_id")
        }
    }
    
    // MARK: - Private Methods
    
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
                }
            }
        }
    }
    
    private func saveServerSettings(baseURL: String, apiKey: String) {
        UserDefaults.standard.set(scheme, forKey: "server_scheme")
        UserDefaults.standard.set(host, forKey: "server_host")
        UserDefaults.standard.set(port, forKey: "server_port")
        UserDefaults.standard.set(baseURL, forKey: "baseURL")
        UserDefaults.standard.set(apiKey, forKey: "apiKey")
        
        NotificationCenter.default.post(name: .init("ServerSettingsChanged"), object: nil)
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
