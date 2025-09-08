import SwiftUI

struct DownloadsView: View {
    @ObservedObject var downloadManager: DownloadManager
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfAPI?
    let onBookSelected: () -> Void
    
    @State private var showingDeleteConfirmation = false
    @State private var bookToDelete: Book?
    
    private let columns = [
        GridItem(.adaptive(minimum: 132, maximum: 160), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if downloadManager.downloadedBooks.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .alert("Buch löschen", isPresented: $showingDeleteConfirmation) {
                Button("Abbrechen", role: .cancel) { }
                Button("Löschen", role: .destructive) {
                    if let book = bookToDelete {
                        downloadManager.deleteBook(book.id)
                    }
                }
            } message: {
                if let book = bookToDelete {
                    Text("Möchten Sie '\(book.title)' wirklich von diesem Gerät löschen?")
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
            
            VStack(spacing: 8) {
                Text("Keine Downloads")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Laden Sie Bücher aus der Bibliothek herunter, um sie offline zu hören")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var contentView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(downloadManager.downloadedBooks) { book in
                    DownloadedBookCardView(
                        book: book,
                        downloadManager: downloadManager,
                        player: player,
                        api: api,
                        onTap: {
                            player.load(book: book, isOffline: true)
                            onBookSelected()
                        },
                        onDelete: {
                            bookToDelete = book
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }
}

struct DownloadedBookCardView: View {
    let book: Book
    @ObservedObject var downloadManager: DownloadManager
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfAPI?
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    
    private var isCurrentBook: Bool {
        player.book?.id == book.id
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                bookCoverView
                bookInfoView
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: isPressed ? 2 : 8,
                        x: 0,
                        y: isPressed ? 1 : 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isCurrentBook ? Color.accentColor : Color.clear,
                        lineWidth: isCurrentBook ? 2 : 0
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private var bookCoverView: some View {
        ZStack {
            // Verwende die BookCoverView für konsistentes Cover-Loading
            BookCoverView(
                book: book,
                api: api,
                downloadManager: downloadManager,
                size: CGSize(width: 150, height: 150)
            )
            
            // Download-Indikator overlay
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.green))
                        .padding(4)
                }
                Spacer()
                
                // Status-Indikator wenn das Buch gerade spielt
                if isCurrentBook {
                    statusIndicator
                }
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
    }
    
    private var bookInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Text(book.author ?? "Unbekannt")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 36)
        .padding(.top, 4)
    }
    
    private var statusIndicator: some View {
        VStack(spacing: 4) {
            Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            Text(player.isPlaying ? "Spielt" : "Pausiert")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.6))
        .clipShape(Capsule())
    }
}
