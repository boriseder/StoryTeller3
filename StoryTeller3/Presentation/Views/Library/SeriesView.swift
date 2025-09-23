import SwiftUI

struct SeriesView: View {
    @StateObject private var viewModel: SeriesViewModel
    
    init(player: AudioPlayer, api: AudiobookshelfAPI, downloadManager: DownloadManager, onBookSelected: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: SeriesViewModel(
            api: api,
            player: player,
            downloadManager: downloadManager,
            onBookSelected: onBookSelected
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else if viewModel.series.isEmpty {
                emptyStateView
            } else {
                contentView
            }
        }
        .navigationTitle(viewModel.libraryName)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchText, prompt: "Serien durchsuchen...")
        .refreshable {
            await viewModel.loadSeries()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if !viewModel.series.isEmpty {
                        sortMenu
                    }
                    settingsButton
                }
            }
        }
        .alert("Fehler", isPresented: $viewModel.showingErrorAlert) {
            Button("OK") { }
            Button("Erneut versuchen") {
                Task { await viewModel.loadSeries() }
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unbekannter Fehler")
        }
        .task {
            await viewModel.loadSeriesIfNeeded()
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
                Task { await viewModel.loadSeries() }
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
                Task { await viewModel.loadSeries() }
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
                    ForEach(viewModel.filteredAndSortedSeries) { series in
                        SeriesSectionView(
                            series: series,
                            player: viewModel.player,
                            api: viewModel.api,
                            downloadManager: viewModel.downloadManager,
                            onBookSelected: {
                                Task {
                                    // falls du ein konkretes Buch laden willst,
                                    // musst du das Buch hier aus `series` auswählen
                                }
                            }
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
                        viewModel.selectedSortOption = option
                    }
                }) {
                    Label(option.rawValue, systemImage: option.systemImage)
                    if viewModel.selectedSortOption == option {
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
}
