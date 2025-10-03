//
//  AdvancedSettingsView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 03.10.25.
//


//
//  AdvancedSettingsView.swift
//  StoryTeller3
//

import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        Form {
            networkSection
            cacheSection
            debugSection
            
            #if DEBUG
            developerSection
            #endif
        }
        .navigationTitle("Advanced Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Network Section
    
    private var networkSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Connection Timeout")
                    Spacer()
                    Text("\(Int(viewModel.connectionTimeout))s")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                
                Slider(value: $viewModel.connectionTimeout, in: 10...60, step: 5)
                    .onChange(of: viewModel.connectionTimeout) { _, _ in
                        viewModel.saveNetworkSettings()
                    }
                
                Text("Time to wait for server response before timing out")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Stepper("Max Concurrent Downloads: \(viewModel.maxConcurrentDownloads)", 
                        value: $viewModel.maxConcurrentDownloads, in: 1...5)
                    .onChange(of: viewModel.maxConcurrentDownloads) { _, _ in
                        viewModel.saveDownloadSettings()
                    }
                
                Text("Higher values may improve download speed but use more bandwidth")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Label("Network Settings", systemImage: "network")
        }
    }
    
    // MARK: - Cache Section
    
    private var cacheSection: some View {
        Section {
            Stepper("Cover Cache Limit: \(viewModel.coverCacheLimit)", 
                    value: $viewModel.coverCacheLimit, in: 50...500, step: 50)
                .onChange(of: viewModel.coverCacheLimit) { _, _ in
                    viewModel.saveCacheSettings()
                }
            
            Stepper("Memory Cache: \(viewModel.memoryCacheSize) MB", 
                    value: $viewModel.memoryCacheSize, in: 25...200, step: 25)
                .onChange(of: viewModel.memoryCacheSize) { _, _ in
                    viewModel.saveCacheSettings()
                }
            
            Button("Reset to Defaults") {
                viewModel.resetCacheDefaults()
            }
            .foregroundColor(.accentColor)
        } header: {
            Label("Cache Configuration", systemImage: "memorychip")
        } footer: {
            Text("Higher limits improve performance but use more device resources. Defaults: 100 covers, 50 MB memory.")
                .font(.caption)
        }
    }
    
    // MARK: - Debug Section
    
    private var debugSection: some View {
        Section {
            Toggle("Enable Debug Logging", isOn: $viewModel.enableDebugLogging)
                .onChange(of: viewModel.enableDebugLogging) { _, newValue in
                    viewModel.toggleDebugLogging(newValue)
                }
            
            if viewModel.enableDebugLogging {
                Button("Export Debug Logs") {
                    viewModel.exportDebugLogs()
                }
                
                if let lastExport = viewModel.lastDebugExport {
                    HStack {
                        Text("Last Export")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(lastExport, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Label("Debug Options", systemImage: "ladybug.fill")
        } footer: {
            Text("Debug logs help diagnose connection and playback issues. Logs are stored locally and can be exported for support.")
                .font(.caption)
        }
    }
    
    // MARK: - Developer Section (DEBUG only)
    
    #if DEBUG
    private var developerSection: some View {
        Section {
            Button("Trigger Memory Warning") {
                CoverCacheManager.shared.triggerCriticalCleanup()
            }
            
            Button("Clear All UserDefaults") {
                viewModel.clearAllUserDefaults()
            }
            .foregroundColor(.red)
            
            Button("Simulate Network Error") {
                viewModel.simulateNetworkError()
            }
            
            Button("Reset All Settings") {
                viewModel.resetAllSettings()
            }
            .foregroundColor(.red)
        } header: {
            Label("Developer Tools", systemImage: "hammer.fill")
        } footer: {
            Text("These options are only available in debug builds and may cause unexpected behavior.")
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
    #endif
}