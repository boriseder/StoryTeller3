import SwiftUI

struct AdvancedSettingsView: View {
    @State private var cacheSize: String = "Berechne..."
    @State private var downloadedBooksCount: Int = 0
    @State private var totalDownloadSize: String = "Berechne..."
    @State private var enableDebugLogging = false
    @State private var connectionTimeout: Double = 30
    @State private var maxConcurrentDownloads: Int = 3
    @State private var showingClearCacheAlert = false
    @State private var showingClearDownloadsAlert = false
    
    private let downloadManager = DownloadManager()
    
    var body: some View {
        NavigationStack {
            Form {
                cacheManagementSection
                downloadSettingsSection
                networkSettingsSection
                debugSettingsSection
                storageInformationSection
            }
            .navigationTitle("Erweiterte Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .onAppear(perform: loadAdvancedSettings)
            .alert("Cache leeren", isPresented: $showingClearCacheAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Löschen", role: .destructive) { clearCache() }
            } message: {
                Text("Möchten Sie den gesamten Cache löschen? Dies kann die App-Performance vorübergehend beeinträchtigen.")
            }
            .alert("Downloads löschen", isPresented: $showingClearDownloadsAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Alle löschen", role: .destructive) { clearAllDownloads() }
            } message: {
                Text("Möchten Sie alle heruntergeladenen Hörbücher löschen? Diese Aktion kann nicht rückgängig gemacht werden.")
            }
        }
    }
    
    // MARK: - Cache Management Section
    private var cacheManagementSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cache-Größe").font(.body)
                    Text("Cover und Metadaten")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(cacheSize)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            Button("Cache leeren") { showingClearCacheAlert = true }
                .foregroundColor(.red)
        } header: {
            Label("Cache-Verwaltung", systemImage: "externaldrive.fill")
        } footer: {
            Text("Der Cache speichert Cover-Bilder und Metadaten für bessere Performance.")
        }
    }
    
    // MARK: - Download Settings Section
    private var downloadSettingsSection: some View {
        Section {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Heruntergeladene Bücher").font(.body)
                        Text("\(downloadedBooksCount) Bücher")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(totalDownloadSize)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gleichzeitige Downloads").font(.body)
                        Text("Maximale Anzahl paralleler Downloads")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("Downloads", selection: $maxConcurrentDownloads) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }
            Button("Alle Downloads löschen") { showingClearDownloadsAlert = true }
                .foregroundColor(.red)
                .disabled(downloadedBooksCount == 0)
        } header: {
            Label("Download-Einstellungen", systemImage: "arrow.down.circle.fill")
        } footer: {
            Text("Mehr parallele Downloads können die Geschwindigkeit erhöhen, aber auch mehr Ressourcen verbrauchen.")
        }
        .onChange(of: maxConcurrentDownloads) { UserDefaults.standard.set($0, forKey: "max_concurrent_downloads") }
    }
    
    // MARK: - Network Settings Section
    private var networkSettingsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Verbindungs-Timeout").font(.body)
                        Text("Sekunden bis Verbindungsabbruch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(Int(connectionTimeout))s")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                Slider(value: $connectionTimeout, in: 10...60, step: 5) {
                    Text("Timeout")
                } minimumValueLabel: {
                    Text("10s").font(.caption).foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("60s").font(.caption).foregroundColor(.secondary)
                }
                .tint(.accentColor)
            }
        } header: {
            Label("Netzwerk-Einstellungen", systemImage: "network")
        } footer: {
            Text("Längere Timeouts können bei langsamen Verbindungen helfen, verbrauchen aber mehr Akku.")
        }
        .onChange(of: connectionTimeout) { UserDefaults.standard.set($0, forKey: "connection_timeout") }
    }
    
    // MARK: - Debug Settings Section
    private var debugSettingsSection: some View {
        Section {
            Toggle(isOn: $enableDebugLogging) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug-Protokollierung").font(.body)
                    Text("Erweiterte Protokollierung aktivieren")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(.accentColor)
            if enableDebugLogging {
                Button("Debug-Log exportieren") { exportDebugLog() }
                    .foregroundColor(.accentColor)
                Button("Debug-Log löschen") { clearDebugLog() }
                    .foregroundColor(.red)
            }
        } header: {
            Label("Debug-Einstellungen", systemImage: "ladybug.fill")
        } footer: {
            Text("Debug-Protokollierung kann bei der Fehlerbehebung helfen, verbraucht aber mehr Speicherplatz.")
        }
        .onChange(of: enableDebugLogging) {
            UserDefaults.standard.set($0, forKey: "enable_debug_logging")
            $0 ? enableDebugMode() : disableDebugMode()
        }
    }
    
    // MARK: - Storage Information Section
    private var storageInformationSection: some View {
        Section {
            VStack(spacing: 12) {
                StorageItem(title: "App-Größe", size: getAppSize(), color: .blue)
                StorageItem(title: "Cache", size: cacheSize, color: .orange)
                StorageItem(title: "Downloads", size: totalDownloadSize, color: .green)
                StorageItem(title: "Verfügbarer Speicher", size: getAvailableStorage(), color: .gray)
            }
            .padding(.vertical, 8)
        } header: {
            Label("Speicher-Informationen", systemImage: "internaldrive.fill")
        }
    }
    
    // MARK: - Helper Methods
    private func loadAdvancedSettings() {
        connectionTimeout = UserDefaults.standard.double(forKey: "connection_timeout")
        if connectionTimeout == 0 { connectionTimeout = 30 }
        
        maxConcurrentDownloads = UserDefaults.standard.integer(forKey: "max_concurrent_downloads")
        if maxConcurrentDownloads == 0 { maxConcurrentDownloads = 3 }
        
        enableDebugLogging = UserDefaults.standard.bool(forKey: "enable_debug_logging")
        
        Task { await calculateStorageInfo() }
    }
    
    private func calculateStorageInfo() async {
        await MainActor.run {
            cacheSize = calculateCacheSize()
            downloadedBooksCount = downloadManager.downloadedBooks.count
            totalDownloadSize = calculateDownloadSize()
        }
    }
    
    // NEU: Ordnergrößen-Berechnung
    private func folderSize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                if values.isRegularFile == true, let fileSize = values.fileSize {
                    total += Int64(fileSize)
                }
            } catch {
                print("Fehler beim Lesen der Dateigröße: \(error)")
            }
        }
        return total
    }
    
    // NEU: Einheitliche Formatierung
    private func formatBytes(_ size: Int64) -> String {
        if size == 0 {
            return "0 kB"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func calculateCacheSize() -> String {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return formatBytes(folderSize(at: cacheURL))
    }
    
    private func calculateDownloadSize() -> String {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let downloadsURL = documentsURL.appendingPathComponent("Downloads")
        return formatBytes(folderSize(at: downloadsURL))
    }
    
    private func getAppSize() -> String {
        let bundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        return formatBytes(folderSize(at: bundleURL))
    }
    
    private func getAvailableStorage() -> String {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSpace = attrs[.systemFreeSize] as? NSNumber {
                return formatBytes(freeSpace.int64Value)
            }
        } catch {
            print("Error getting available storage: \(error)")
        }
        return "Unbekannt"
    }
    
    private func clearCache() {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
            for file in contents { try FileManager.default.removeItem(at: file) }
            Task { await calculateStorageInfo() }
        } catch {
            print("Error clearing cache: \(error)")
        }
    }
    
    private func clearAllDownloads() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let downloadsURL = documentsURL.appendingPathComponent("Downloads")
        do {
            try FileManager.default.removeItem(at: downloadsURL)
            try FileManager.default.createDirectory(at: downloadsURL, withIntermediateDirectories: true)
            downloadManager.downloadedBooks.removeAll()
            Task { await calculateStorageInfo() }
        } catch {
            print("Error clearing downloads: \(error)")
        }
    }
    
    private func exportDebugLog() { print("Exporting debug log...") }
    private func clearDebugLog() { print("Clearing debug log...") }
    private func enableDebugMode() { print("Debug mode enabled") }
    private func disableDebugMode() { print("Debug mode disabled") }
}

// MARK: - Storage Item View
struct StorageItem: View {
    let title: String
    let size: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(title).font(.body)
            Spacer()
            Text(size).font(.headline).foregroundColor(.secondary)
        }
    }
}
