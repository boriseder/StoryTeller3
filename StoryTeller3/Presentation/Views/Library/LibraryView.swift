import SwiftUI

struct LibraryView: View {
    @StateObject private var viewModel: LibraryViewModel
    @State private var selectedSeries: Book? // ← NEU: Für Series Modal
    
    init(player: AudioPlayer, api: AudiobookshelfAPI, downloadManager: DownloadManager, onBookSelected: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: LibraryViewModel(
            api: api,
            player: player,
            downloadManager: downloadManager,
            onBookSelected: onBookSelected
        ))
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 132, maximum: 160), spacing: 16)
    ]

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else if viewModel.books.isEmpty {
                emptyStateView
            } else if viewModel.filteredAndSortedBooks.isEmpty && viewModel.showDownloadedOnly {
                noDownloadsView
            } else if viewModel.filteredAndSortedBooks.isEmpty {
                noSearchResultsView
            } else {
                contentView
            }
        }
        .navigationTitle(viewModel.libraryName)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchText, prompt: "Bücher durchsuchen...")
        .refreshable {
            await viewModel.loadBooks()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if !viewModel.books.isEmpty {
                        filterAndSortMenu
                    }
                    settingsButton
                }
            }
        }
        .alert("Fehler", isPresented: $viewModel.showingErrorAlert) {
            Button("OK") { }
            Button("Erneut versuchen") {
                Task { await viewModel.loadBooks() }
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unbekannter Fehler")
        }
        .task {
            await viewModel.loadBooksIfNeeded()
        }
        // ← NEU: Series Modal (temporär auskommentiert bis SeriesDetailModalView erstellt ist)
        .sheet(item: $selectedSeries) { series in
            // Temporärer Fallback bis SeriesDetailModalView verfügbar ist
            NavigationStack {
                VStack {
                    Text("Serie: \(series.displayTitle)")
                        .font(.title2)
                        .padding()
                    
                    Text("Hier wird später die SeriesDetailModalView angezeigt")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Spacer()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Fertig") {
                            selectedSeries = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Lade deine Bibliothek...")
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
                Task { await viewModel.loadBooks() }
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
                Text("Deine Bibliothek ist leer")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Füge Hörbücher zu deiner Audiobookshelf-Bibliothek hinzu")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task { await viewModel.loadBooks() }
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
    
    private var noDownloadsView: some View {
        VStack(spacing: 32) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 80))
                .foregroundStyle(.orange.gradient)
            
            VStack(spacing: 8) {
                Text("Keine Downloads gefunden")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Du hast noch keine Bücher heruntergeladen. Lade Bücher herunter, um sie offline zu hören.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    viewModel.toggleDownloadFilter()
                }) {
                    Label("Alle Bücher anzeigen", systemImage: "eye")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    Task { await viewModel.loadBooks() }
                }) {
                    Label("Aktualisieren", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noSearchResultsView: some View {
        VStack(spacing: 32) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 80))
                .foregroundStyle(.gray.gradient)
            
            VStack(spacing: 8) {
                Text("Keine Suchergebnisse")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Versuche einen anderen Suchbegriff oder überprüfe die Schreibweise.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                viewModel.searchText = ""
            }) {
                Label("Suche zurücksetzen", systemImage: "xmark.circle")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.secondary.opacity(0.1))
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
            
            VStack(spacing: 0) {
                // Filter-Status-Banner (wenn Download-Filter aktiv)
                if viewModel.showDownloadedOnly {
                    filterStatusBanner
                }
                
                // ← NEU: Series-Status-Banner (wenn Series-Modus aktiv)
                if viewModel.showSeriesGrouped {
                    seriesStatusBanner
                }
                
                ScrollView {
                    // ← VEREINFACHT: Normale Grid-Darstellung (gleich für Bücher und Serien)
                    LazyVGrid(columns: columns, spacing: 32) {
                        ForEach(viewModel.filteredAndSortedBooks) { book in
                            BookCardView.library(
                                book: book,
                                player: viewModel.player,
                                api: viewModel.api,
                                downloadManager: viewModel.downloadManager,
                                onTap: {
                                    handleBookTap(book)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 16)
                }
            }
        }
    }
    
    // MARK: - ← NEU: Book Tap Handling
    
    private func handleBookTap(_ book: Book) {
        if book.isCollapsedSeries {
            // Serie → Modal öffnen
            selectedSeries = book
        } else {
            // Einzelbuch → Playback wie bisher
            Task {
                await viewModel.loadAndPlayBook(book)
            }
        }
    }
    
    // MARK: - Status Banners
    
    private var filterStatusBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
            
            Text("Zeige \(viewModel.filteredAndSortedBooks.count) von \(viewModel.downloadedBooksCount) heruntergeladenen Büchern")
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                viewModel.toggleDownloadFilter()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    // ← NEU: Series Status Banner
    private var seriesStatusBanner: some View {
        let seriesCount = viewModel.filteredAndSortedBooks.filter { $0.isCollapsedSeries }.count
        let booksCount = viewModel.filteredAndSortedBooks.filter { !$0.isCollapsedSeries }.count
        
        return HStack(spacing: 12) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 16))
                .foregroundColor(.blue)
            
            if seriesCount > 0 && booksCount > 0 {
                Text("Zeige \(seriesCount) Serien • \(booksCount) Bücher")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            } else if seriesCount > 0 {
                Text("Zeige \(seriesCount) Serien")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            } else {
                Text("Zeige \(booksCount) Bücher")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Button(action: {
                viewModel.toggleSeriesMode()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }

    // MARK: - Toolbar Components
    
    private var filterAndSortMenu: some View {
        Menu {
            // Sortierung Section
            Section("Sortieren nach") {
                ForEach(LibrarySortOption.allCases, id: \.self) { option in
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
            }
            
            Divider()
            
            // Filter Section
            Section("Filter") {
                Button(action: {
                    viewModel.toggleDownloadFilter()
                }) {
                    Label("Nur Heruntergeladene", systemImage: "arrow.down.circle")
                    if viewModel.showDownloadedOnly {
                        Image(systemName: "checkmark")
                    }
                }
                
                if viewModel.downloadedBooksCount > 0 {
                    Text("\(viewModel.downloadedBooksCount) heruntergeladen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Darstellung Section
            Section("Darstellung") {
                Button(action: {
                    viewModel.toggleSeriesMode()
                }) {
                    Label("Serien gebündelt", systemImage: "rectangle.stack")
                    if viewModel.showSeriesGrouped {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            // Statistik Section
            Section("Bibliothek") {
                if viewModel.showSeriesGrouped {
                    let seriesCount = viewModel.filteredAndSortedBooks.filter { $0.isCollapsedSeries }.count
                    let booksCount = viewModel.filteredAndSortedBooks.filter { !$0.isCollapsedSeries }.count
                    
                    HStack {
                        Text("Gesamt: \(seriesCount) Serien • \(booksCount) Bücher")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    HStack {
                        Text("Gesamt: \(viewModel.totalBooksCount) Bücher")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            
            // Reset Section (nur wenn Filter aktiv)
            if viewModel.showDownloadedOnly || viewModel.showSeriesGrouped || !viewModel.searchText.isEmpty {
                Divider()
                
                Section {
                    Button(action: {
                        viewModel.resetFilters()
                    }) {
                        Label("Filter zurücksetzen", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            
        } label: {
            ZStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                
                // Badge wenn Filter aktiv
                if viewModel.showDownloadedOnly || viewModel.showSeriesGrouped {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                        .offset(x: 8, y: -8)
                }
            }
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
