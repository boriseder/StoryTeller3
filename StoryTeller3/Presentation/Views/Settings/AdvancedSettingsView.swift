import SwiftUI

struct AdvancedSettingsView: View {
    @StateObject private var vm = AdvancedSettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                cacheSection
                coverCacheSection
                downloadSection
                networkSection
                debugSection
            }
            .navigationTitle("Erweiterte Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { vm.loadSettings() }
            .refreshable { await vm.calculateStorageInfo() }
            .alert("App-Cache leeren", isPresented: $vm.showingClearAppCacheAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) { Task { await vm.clearAppCache() } }
            }
            .alert("Kompletten Cache leeren", isPresented: $vm.showingClearAllCacheAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Alles löschen", role: .destructive) { Task { await vm.clearCompleteCache() } }
            }
            .alert("Downloads löschen", isPresented: $vm.showingClearDownloadsAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Alle löschen", role: .destructive) { Task { await vm.clearAllDownloads() } }
            }
            .alert("Cover-Cache verwalten", isPresented: $vm.showingClearCoverCacheAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Nur Memory", role: .destructive) { vm.clearCoverMemoryCache() }
                Button("Alles löschen", role: .destructive) { vm.coverCacheManager.clearAllCache() }
            }
        }
    }

    private var cacheSection: some View {
        Section {
            HStack { Text("App-Cache"); Spacer(); Text(vm.appCacheSize).foregroundColor(.secondary) }
            Button("App-Cache leeren") { vm.showingClearAppCacheAlert = true }.foregroundColor(.orange)
            Button("Kompletten Cache leeren") { vm.showingClearAllCacheAlert = true }.foregroundColor(.red)
        } header: {
            Label("Cache-Verwaltung", systemImage: "externaldrive.fill")
        }
    }

    private var coverCacheSection: some View {
        Section {
            HStack { Text("Cover-Cache"); Spacer(); Text(vm.coverCacheSize).foregroundColor(.secondary) }
            Stepper("Memory Cache Limit: \(vm.coverCacheLimit)", value: $vm.coverCacheLimit, in: 50...200, step: 10) {_ in 
                vm.saveCoverCacheSettings()
            }
            Stepper("Memory Size: \(vm.memoryCacheSize) MB", value: $vm.memoryCacheSize, in: 25...200, step: 5) {_ in 
                vm.saveCoverCacheSettings()
            }
            Button("Cover-Cache verwalten") { vm.showingClearCoverCacheAlert = true }.foregroundColor(.blue)
        } header: {
            Label("Cover-Cache", systemImage: "photo.stack.fill")
        }
    }

    private var downloadSection: some View {
        Section {
            HStack { Text("Heruntergeladene Bücher"); Spacer(); Text("\(vm.downloadedBooksCount)").foregroundColor(.secondary) }
            Stepper("Max. gleichzeitige Downloads: \(vm.maxConcurrentDownloads)", value: $vm.maxConcurrentDownloads, in: 1...5) {_ in 
                vm.saveDownloadSettings()
            }
            Button("Alle Downloads löschen") { vm.showingClearDownloadsAlert = true }.foregroundColor(.red).disabled(vm.downloadedBooksCount == 0)
        } header: {
            Label("Download-Einstellungen", systemImage: "arrow.down.circle.fill")
        }
    }

    private var networkSection: some View {
        Section {
            VStack(alignment: .leading) {
                Text("Verbindungs-Timeout: \(Int(vm.connectionTimeout))s")
                Slider(value: $vm.connectionTimeout, in: 10...60, step: 5) { _ in vm.saveNetworkSettings() }
            }
        } header: {
            Label("Netzwerk-Einstellungen", systemImage: "network")
        }
    }

    private var debugSection: some View {
        Section {
            Toggle("Debug-Protokollierung", isOn: $vm.enableDebugLogging).onChange(of: vm.enableDebugLogging) { vm.toggleDebugLogging($0) }
        } header: {
            Label("Debug-Einstellungen", systemImage: "ladybug.fill")
        }
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
