import SwiftUI

struct LibraryView: View {
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfAPI
    @ObservedObject var downloadManager: DownloadManager
    let onBookSelected: () -> Void
    
    @State private var books: [Book] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var searchText = ""
    @State private var selectedSortOption: SortOption = .title
    @State private var libraryName: String = "Meine Bibliothek"
    
    private let columns = [
        GridItem(.adaptive(minimum: 132, maximum: 160), spacing: 16)
    ]
    
    enum SortOption: String, CaseIterable {
        case title = "Titel"
        case author = "Autor"
        case recent = "Zuletzt hinzugefügt"
        
        var systemImage: String {
            switch self {
            case .title: return "textformat.abc"
            case .author: return "person.fill"
            case .recent: return "clock.fill"
            }
        }
    }
    
    private var filteredAndSortedBooks: [Book] {
        let filtered = searchText.isEmpty ? books : books.filter { book in
            book.title.localizedCaseInsensitiveContains(searchText) ||
            (book.author?.localizedCaseInsensitiveContains(searchText) ?? false)
        }

        return filtered.sorted { book1, book2 in
            switch selectedSortOption {
            case .title:
                return book1.title.localizedCompare(book2.title) == .orderedAscending
            case .author:
                return (book1.author ?? "Unbekannt").localizedCompare(book2.author ?? "Unbekannt") == .orderedAscending
            case .recent:
                return book1.id > book2.id
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if books.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle(libraryName)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Bücher durchsuchen...")
            .refreshable {
                await loadBooks()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    sortMenu
                }
            }
            .alert("Fehler", isPresented: $showingErrorAlert) {
                Button("OK") { }
                Button("Erneut versuchen") {
                    Task { await loadBooks() }
                }
            } message: {
                Text(errorMessage ?? "Unbekannter Fehler")
            }
        }
        .task {
            if books.isEmpty {
                await loadBooks()
            }
        }
    }
    
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
                Task { await loadBooks() }
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
                Task { await loadBooks() }
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
                LazyVGrid(columns: columns, spacing: 32) {
                    ForEach(filteredAndSortedBooks) { book in
                        BookCardView(
                            book: book,
                            player: player,
                            api: api,
                            downloadManager: downloadManager,
                            onTap: {
                                Task {
                                    await loadAndPlayBook(book)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 16)
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SortOption.allCases, id: \.self) { option in
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
                .imageScale(.large)
        }
    }
    
    // MARK: - Data Loading Methods
    
    @MainActor
    private func loadBooks() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedBooks: [Book]
            
            if let libraryId = UserDefaults.standard.string(forKey: "selected_library_id") {
                let libraries = try await api.fetchLibraries()
                if let selectedLibrary = libraries.first(where: { $0.id == libraryId }) {
                    libraryName = selectedLibrary.name
                    fetchedBooks = try await api.fetchBooks(from: libraryId)
                    print("\(fetchedBooks.count) Bücher aus Bibliothek '\(selectedLibrary.name)' geladen")
                } else {
                    throw AudiobookshelfError.libraryNotFound("Selected library not found")
                }
            } else {
                let libraries = try await api.fetchLibraries()
                if let firstLibrary = libraries.first {
                    libraryName = firstLibrary.name
                    fetchedBooks = try await api.fetchBooks(from: firstLibrary.id)
                    UserDefaults.standard.set(firstLibrary.id, forKey: "selected_library_id")
                    print("\(fetchedBooks.count) Bücher aus Standard-Bibliothek '\(firstLibrary.name)' geladen")
                } else {
                    libraryName = "Keine Bibliothek"
                    fetchedBooks = []
                }
            }
            
            // Update books with animation
            withAnimation(.easeInOut) {
                books = fetchedBooks
            }
            
            // Optional: Preload first 10 covers for better UX
            if !fetchedBooks.isEmpty {
                CoverCacheManager.shared.preloadCovers(
                    for: Array(fetchedBooks.prefix(10)),
                    api: api,
                    downloadManager: downloadManager
                )
            }
            
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
            print("Fehler beim Laden der Bücher: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    private func loadAndPlayBook(_ book: Book) async {
        print("Lade Buch: \(book.title)")
        
        do {
            let fetchedBook = try await api.fetchBookDetails(bookId: book.id)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            player.load(book: fetchedBook)
            onBookSelected()
            print("Buch '\(fetchedBook.title)' geladen")
            print("Buch von '\(fetchedBook.author ?? "Unbekannt")'")

        } catch {
            errorMessage = "Konnte '\(book.title)' nicht laden: \(error.localizedDescription)"
            showingErrorAlert = true
            print("Fehler beim Laden der Buchdetails: \(error)")
        }
    }
}
