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
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(filteredAndSortedBooks) { book in
                    BookCardView(
                        book: book,
                        player: player,
                        api: api,
                        downloadManager: downloadManager,
                        onTap: {
                            Task {
                                await loadBookDetails(for: book)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 8)
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
    
    @MainActor
    private func loadBooks() async {
        isLoading = true
        errorMessage = nil
        
        do {
            if let libraryId = UserDefaults.standard.string(forKey: "selected_library_id") {
                let libraries = try await api.fetchLibraries()
                if let selectedLibrary = libraries.first(where: { $0.id == libraryId }) {
                    libraryName = selectedLibrary.name
                    let fetchedBooks = try await api.fetchBooks(from: libraryId)
                    withAnimation(.easeInOut) {
                        books = fetchedBooks
                    }
                    print("\(fetchedBooks.count) Bücher aus Bibliothek '\(selectedLibrary.name)' geladen")
                } else {
                    throw AudiobookshelfError.libraryNotFound("Selected library not found")
                }
            } else {
                let libraries = try await api.fetchLibraries()
                if let firstLibrary = libraries.first {
                    libraryName = firstLibrary.name
                    let fetchedBooks = try await api.fetchBooks(from: firstLibrary.id)
                    withAnimation(.easeInOut) {
                        books = fetchedBooks
                    }
                    UserDefaults.standard.set(firstLibrary.id, forKey: "selected_library_id")
                    print("\(fetchedBooks.count) Bücher aus Standard-Bibliothek '\(firstLibrary.name)' geladen")
                } else {
                    libraryName = "Keine Bibliothek"
                    books = []
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
            print("Fehler beim Laden der Bücher: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    private func loadBookDetails(for book: Book) async {
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

// Ersatz für die bookCoverView in LibraryView.swift -> BookCardView
// Diese View sollte die bestehende Cover-Logik in BookCardView ersetzen:

struct BookCardCoverView: View {
    let book: Book
    let api: AudiobookshelfAPI
    let downloadManager: DownloadManager
    let height: CGFloat = 150
    
    @State private var coverImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let coverImage = coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(8)
            } else if isLoading {
                loadingPlaceholder
            } else {
                placeholderCoverView
            }
        }
        .onAppear {
            loadCoverImage()
        }
    }
    
    private var loadingPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.3)
            
            ProgressView()
                .scaleEffect(0.8)
        }
        .frame(height: height)
        .cornerRadius(8)
    }
    
    private var placeholderCoverView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.3),
                    Color.accentColor.opacity(0.6),
                    Color.accentColor.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Image(systemName: "book.closed.fill")
                .font(.system(size: 32))
                .foregroundColor(.white)
        }
        .frame(height: height)
        .cornerRadius(8)
    }
    
    private func loadCoverImage() {
        // 1. Zuerst lokales Cover prüfen (Offline-Modus)
        if let localCoverURL = downloadManager.getLocalCoverURL(for: book.id),
           let localImage = UIImage(contentsOfFile: localCoverURL.path) {
            self.coverImage = localImage
            self.isLoading = false
            return
        }
        
        // 2. Online-Cover laden wenn kein lokales vorhanden
        guard let coverPath = book.coverPath else {
            self.isLoading = false
            return
        }
        
        let coverURL = "\(api.baseURLString)\(coverPath)"
        guard let url = URL(string: coverURL) else {
            self.isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(api.authToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let data = data, let image = UIImage(data: data) {
                    self.coverImage = image
                }
            }
        }.resume()
    }
}

// Diese Änderung in LibraryView.swift in der BookCardView anwenden:
// Ersetze die bestehende bookCoverView durch:
/*
private var bookCoverView: some View {
    BookCardCoverView(
        book: book,
        api: api,
        downloadManager: downloadManager
    )
    .overlay(
        VStack {
            HStack {
                Spacer()
                if downloadManager.isBookDownloaded(book.id) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.green))
                        .padding(4)
                }
            }
            Spacer()
        }
    )
}
*/
