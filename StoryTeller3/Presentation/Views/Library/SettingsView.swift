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
                
                advancedSettingsSection
            }
            .navigationTitle("Einstellungen")
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
    private var advancedSettingsSection: some View {
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
}
