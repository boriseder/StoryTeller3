import SwiftUI

struct AdvancedSettingsView: View {
    // MARK: - State
    @State private var appCacheSize: String = "Berechne..."
    @State private var coverCacheSize: String = "Berechne..."
    @State private var downloadedBooksCount: Int = 0
    @State private var totalDownloadSize: String = "Berechne..."
    @State private var enableDebugLogging = false
    @State private var connectionTimeout: Double = 30
    @State private var maxConcurrentDownloads: Int = 3
    @State private var coverCacheLimit: Int = 100
    @State private var memoryCacheSize: Int = 50
    
    // Alert states
    @State private var showingClearAppCacheAlert = false
    @State private var showingClearCoverCacheAlert = false
    @State private var showingClearDownloadsAlert = false
    @State private var showingClearAllCacheAlert = false
    
    // Cache managers
    private let downloadManager = DownloadManager()
    @StateObject private var coverCacheManager = CoverCacheManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                cacheManagementSection
                coverCacheSection
                downloadSettingsSection
                networkSettingsSection
                debugSettingsSection
                storageInformationSection
            }
            .navigationTitle("Erweiterte Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .onAppear(perform: loadAdvancedSettings)
            .refreshable {
                await calculateStorageInfo()
            }
            
            // MARK: - Alerts
            .alert("App-Cache leeren", isPresented: $showingClearAppCacheAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Löschen", role: .destructive) { clearAppCache() }
            } message: {
                Text("Möchten Sie den gesamten App-Cache löschen? Dies kann die App-Performance vorübergehend beeinträchtigen.")
            }
            
            .alert("Cover-Cache leeren", isPresented: $showingClearCoverCacheAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Nur Memory", role: .destructive) { clearCoverMemoryCache() }
                Button("Alles löschen", role: .destructive) { clearAllCoverCache() }
            } message: {
                Text("Cover müssen nach dem Löschen erneut geladen werden.")
            }
            
            .alert("Downloads löschen", isPresented: $showingClearDownloadsAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Alle löschen", role: .destructive) { clearAllDownloads() }
            } message: {
                Text("Möchten Sie alle heruntergeladenen Hörbücher löschen? Diese Aktion kann nicht rückgängig gemacht werden.")
            }
            
            .alert("Kompletten Cache leeren", isPresented: $showingClearAllCacheAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Alles löschen", role: .destructive) { clearCompleteCache() }
            } message: {
                Text("Dies löscht alle zwischengespeicherten Daten. Die App muss alle Inhalte erneut laden.")
            }
        }
    }
    
    // MARK: - Cache Management Section
    private var cacheManagementSection: some View {
        Section {
            // App Cache
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("App-Cache").font(.body)
                    Text("Temporäre Daten und Metadaten")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(appCacheSize)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            Button("App-Cache leeren") {
                showingClearAppCacheAlert = true
            }
            .foregroundColor(.orange)
            
            Divider()
            
            // Complete Cache Clear
            Button("Kompletten Cache leeren") {
                showingClearAllCacheAlert = true
            }
            .foregroundColor(.red)
            .font(.headline)
            
        } header: {
            Label("Cache-Verwaltung", systemImage: "externaldrive.fill")
        } footer: {
            Text("Der App-Cache speichert temporäre Daten für bessere Performance.")
        }
    }
    
    // MARK: - Cover Cache Section
    private var coverCacheSection: some View {
        Section {
            // Cover Cache Size
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cover-Cache").font(.body)
                    Text("Buchcover (Memory + Disk)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(coverCacheSize)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Memory Cache Limit
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Memory Cache Limit").font(.body)
                        Text("Anzahl Cover im Arbeitsspeicher")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("Cover Limit", selection: $coverCacheLimit) {
                        ForEach([50, 100, 150, 200], id: \.self) { limit in
                            Text("\(limit)").tag(limit)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Memory Size Limit
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Memory Size Limit").font(.body)
                        Text("Maximaler Speicher für Cover")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("Memory Size", selection: $memoryCacheSize) {
                        ForEach([25, 50, 75, 100], id: \.self) { size in
                            Text("\(size) MB").tag(size)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            // Cover Cache Actions
            Button("Cover-Cache verwalten") {
                showingClearCoverCacheAlert = true
            }
            .foregroundColor(.blue)
            
        } header: {
            Label("Cover-Cache", systemImage: "photo.stack.fill")
        } footer: {
            Text("Cover werden automatisch zwischengespeichert. Höhere Limits verbessern Performance, verbrauchen aber mehr Speicher.")
        }
        .onChange(of: coverCacheLimit) { saveCoverCacheSettings() }
        .onChange(of: memoryCacheSize) { saveCoverCacheSettings() }
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
            
            Button("Alle Downloads löschen") {
                showingClearDownloadsAlert = true
            }
            .foregroundColor(.red)
            .disabled(downloadedBooksCount == 0)
            
        } header: {
            Label("Download-Einstellungen", systemImage: "arrow.down.circle.fill")
        } footer: {
            Text("Mehr parallele Downloads können die Geschwindigkeit erhöhen, aber auch mehr Ressourcen verbrauchen.")
        }
        .onChange(of: maxConcurrentDownloads) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "max_concurrent_downloads")
        }
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
        .onChange(of: connectionTimeout) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "connection_timeout")
        }
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
        .onChange(of: enableDebugLogging) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "enable_debug_logging")
            newValue ? enableDebugMode() : disableDebugMode()
        }
    }
    
    // MARK: - Storage Information Section
    private var storageInformationSection: some View {
        Section {
            VStack(spacing: 12) {
                StorageItem(title: "App-Größe", size: getAppSize(), color: .blue)
                StorageItem(title: "App-Cache", size: appCacheSize, color: .orange)
                StorageItem(title: "Cover-Cache", size: coverCacheSize, color: .purple)
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
        
        coverCacheLimit = UserDefaults.standard.integer(forKey: "cover_cache_limit")
        if coverCacheLimit == 0 { coverCacheLimit = 100 }
        
        memoryCacheSize = UserDefaults.standard.integer(forKey: "memory_cache_size")
        if memoryCacheSize == 0 { memoryCacheSize = 50 }
        
        enableDebugLogging = UserDefaults.standard.bool(forKey: "enable_debug_logging")
        
        Task { await calculateStorageInfo() }
    }
    
    private func saveCoverCacheSettings() {
        UserDefaults.standard.set(coverCacheLimit, forKey: "cover_cache_limit")
        UserDefaults.standard.set(memoryCacheSize, forKey: "memory_cache_size")
        
        // Apply new cache settings
        Task { @MainActor in
            await applyCacheSettings()
        }
    }
    
    @MainActor
    private func applyCacheSettings() async {
        // This would require extending CoverCacheManager to accept dynamic limits
        // For now, we'll just save the preferences
        AppLogger.debug.debug("Applied new cache settings: \(coverCacheLimit) covers, \(memoryCacheSize) MB")
    }
    
    private func calculateStorageInfo() async {
        await MainActor.run {
            appCacheSize = calculateAppCacheSize()
            coverCacheSize = calculateCoverCacheSize()
            downloadedBooksCount = downloadManager.downloadedBooks.count
            totalDownloadSize = calculateDownloadSize()
        }
    }
    
    // MARK: - Size Calculations
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
                AppLogger.debug.debug("Fehler beim Lesen der Dateigröße: \(error)")
            }
        }
        return total
    }
    
    private func formatBytes(_ size: Int64) -> String {
        if size == 0 {
            return "0 kB"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func calculateAppCacheSize() -> String {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let totalSize = folderSize(at: cacheURL)
        let coverCacheSize = CoverCacheManager.shared.getCacheSize()
        let appCacheSize = totalSize - coverCacheSize
        return formatBytes(max(0, appCacheSize))
    }
    
    private func calculateCoverCacheSize() -> String {
        let size = CoverCacheManager.shared.getCacheSize()
        return formatBytes(size)
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
            AppLogger.debug.debug("Error getting available storage: \(error)")
        }
        return "Unbekannt"
    }
    
    // MARK: - Cache Clearing Methods
    private func clearAppCache() {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let coverCacheURL = cacheURL.appendingPathComponent("BookCovers")
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
            for file in contents {
                // Skip cover cache directory
                if file != coverCacheURL {
                    try FileManager.default.removeItem(at: file)
                }
            }
            Task { await calculateStorageInfo() }
        } catch {
            AppLogger.debug.debug("Error clearing app cache: \(error)")
        }
    }
    
    private func clearCoverMemoryCache() {
        CoverCacheManager.shared.clearMemoryCache()
        Task { await calculateStorageInfo() }
    }
    
    private func clearAllCoverCache() {
        CoverCacheManager.shared.clearAllCache()
        Task { await calculateStorageInfo() }
    }
    
    private func clearAllDownloads() {
        downloadManager.deleteAllBooks()
        Task { await calculateStorageInfo() }
    }
    
    private func clearCompleteCache() {
        // Clear app cache
        clearAppCache()
        // Clear cover cache
        clearAllCoverCache()
        
        Task { await calculateStorageInfo() }
    }
    
    // MARK: - Debug Methods
    private func exportDebugLog() {
        AppLogger.debug.debug("Exporting debug log...")
    }
    
    private func clearDebugLog() {
        AppLogger.debug.debug("Clearing debug log...")
    }
    
    private func enableDebugMode() {
        AppLogger.debug.debug("Debug mode enabled")
    }
    
    private func disableDebugMode() {
        AppLogger.debug.debug("Debug mode disabled")
    }
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
