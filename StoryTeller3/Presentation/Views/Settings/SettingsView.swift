//
//  SettingsView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 09.09.25.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationStack {
            Form {
                serverSection
                apiKeySection
                connectionSection
                
                if !viewModel.libraries.isEmpty {
                    librariesSection
                }
                
                advancedSettingsSection
            }
            .navigationTitle("Einstellungen")
            .onAppear {
                // ViewModel lädt die Einstellungen automatisch im init()
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
            TextField("Host", text: $viewModel.host)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            TextField("Port", text: $viewModel.port)
                .keyboardType(.numberPad)
        }
        .onChange(of: viewModel.host) { _, _ in viewModel.autoTestConnection() }
        .onChange(of: viewModel.port) { _, _ in viewModel.autoTestConnection() }
        .onChange(of: viewModel.scheme) { _, _ in viewModel.autoTestConnection() }
    }
    
    // MARK: - API Key Section
    private var apiKeySection: some View {
        Section(header: Text("API Key")) {
            SecureField("API Key", text: $viewModel.apiKey)
                .onChange(of: viewModel.apiKey) { _, newValue in
                    viewModel.onApiKeyChanged(newValue)
                }
        }
    }
    
    // MARK: - Connection Section
    private var connectionSection: some View {
        Section {
            if viewModel.isLoading {
                connectionLoadingView
            } else if !viewModel.connectionStatus.isEmpty {
                connectionStatusView
                
                if viewModel.showLoginButton {
                    loginButton
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
            Button {
                viewModel.autoTestConnection()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
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
            
            logoutButton
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
