import SwiftUI

struct SeriesView: View {
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfAPI
    @ObservedObject var downloadManager: DownloadManager
    let onBookSelected: () -> Void
    
    @State private var series: [Series] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var searchText = ""
    @State private var selectedSortOption: SeriesSortOption = .name
    @State private var libraryName: String = "Serien"
    
    private var filteredAndSortedSeries: [Series] {
        let filtered = searchText.isEmpty ? series : series.filter { series in
            series.name.localizedCaseInsensitiveContains(searchText) ||
            (series.author?.localizedCaseInsensitiveContains(searchText) ?? false)
        }

        return filtered.sorted { series1, series2 in
            switch selectedSortOption {
            case .name:
                return series1.name.localizedCompare(series2.name) == .orderedAscending
            case .recent:
                return series1.addedAt > series2.addedAt
            case .bookCount:
                return series1.bookCount > series2.bookCount
            case .duration:
                return series1.totalDuration > series2.totalDuration
            }
        }
    }

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if series.isEmpty {
                emptyStateView
            } else {
                contentView
            }
        }
        .navigationTitle(libraryName)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Serien durchsuchen...")
        .refreshable {
            await loadSeries()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if !series.isEmpty {
                        sortMenu
                    }
                    settingsButton
                }
            }
        }
        .alert("Fehler", isPresented: $showingErrorAlert) {
            Button("OK") { }
            Button("Erneut versuchen") {
                Task { await loadSeries() }
            }
        } message: {
            Text(errorMessage ?? "Unbekannter Fehler")
        }
        .task {
            if series.isEmpty {
                await loadSeries()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Lade Serien...")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 60))
                .foregroundStyle(.red.gradient)
            
            VStack(spacing: 12) {
                Text("Verbindungsfehler")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                Task { await loadSeries() }
            }) {
                Label("Erneut versuchen", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.accentColor.gradient)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Image(systemName: "books.vertical.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
            
            VStack(spacing: 8) {
                Text("Keine Serien gefunden")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Es wurden keine Buchserien in deiner Bibliothek gefunden")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task { await loadSeries() }
            }) {
                Label("Aktualisieren", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var contentView: some View {
        ZStack {
            DynamicMusicBackground()
            
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(filteredAndSortedSeries) { series in
                        SeriesRowView(
                            series: series,
                            player: player,
                            api: api,
                            downloadManager: downloadManager,
                            onBookSelected: onBookSelected
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
    }
    
    // MARK: - Toolbar Components
    
    private var sortMenu: some View {
        Menu {
            ForEach(SeriesSortOption.allCases, id: \.self) { option in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSortOption = option
                    }
                }) {
                    Label(option.rawValue, systemImage: option.systemImage)
                    if selectedSortOption == option {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 16))
                .foregroundColor(.primary)
        }
    }
    
    private var settingsButton: some View {
        Button(action: {
            NotificationCenter.default.post(name: .init("ShowSettings"), object: nil)
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadSeries() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedSeries: [Series]
            
            if let libraryId = UserDefaults.standard.string(forKey: "selected_library_id") {
                let libraries = try await api.fetchLibraries()
                if let selectedLibrary = libraries.first(where: { $0.id == libraryId }) {
                    libraryName = "\(selectedLibrary.name) - Serien"
                    fetchedSeries = try await api.fetchSeries(from: libraryId)
                    print("\(fetchedSeries.count) Serien aus Bibliothek '\(selectedLibrary.name)' geladen")
                } else {
                    throw AudiobookshelfError.libraryNotFound("Selected library not found")
                }
            } else {
                let libraries = try await api.fetchLibraries()
                if let firstLibrary = libraries.first {
                    libraryName = "\(firstLibrary.name) - Serien"
                    fetchedSeries = try await api.fetchSeries(from: firstLibrary.id)
                    UserDefaults.standard.set(firstLibrary.id, forKey: "selected_library_id")
                    print("\(fetchedSeries.count) Serien aus Standard-Bibliothek '\(firstLibrary.name)' geladen")
                } else {
                    libraryName = "Serien"
                    fetchedSeries = []
                }
            }
            
            // Update series with animation
            withAnimation(.easeInOut) {
                series = fetchedSeries
            }
            
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
            print("Fehler beim Laden der Serien: \(error)")
        }
        
        isLoading = false
    }
}
