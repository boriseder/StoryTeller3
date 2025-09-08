import SwiftUI

struct BookCardView: View {
    // MARK: - Properties
    let book: Book
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfAPI
    @ObservedObject var downloadManager: DownloadManager
    let onTap: () -> Void
    
    // MARK: - State
    @State private var isPressed = false
    @State private var showingDownloadProgress = false
    
    // MARK: - Computed Properties
    private var isCurrentBook: Bool {
        player.book?.id == book.id
    }
    
    private var downloadProgress: Double {
        downloadManager.getDownloadProgress(for: book.id)
    }
    
    private var isDownloaded: Bool {
        downloadManager.isBookDownloaded(book.id)
    }
    
    private var isDownloading: Bool {
        downloadManager.isDownloadingBook(book.id)
    }
    
    // MARK: - Body
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                bookCoverSection
                    .frame(height: 160) // ← Cover fest oben
                
                Spacer() // ← Nimmt allen verfügbaren Platz
                
                bookInfoSection
                    .frame(height: 60) // ← Info fest unten
            }
            .frame(height: 220)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(
                        color: .black.opacity(0.1),
                        radius: isPressed ? 4 : 12,
                        x: 0,
                        y: isPressed ? 2 : 6
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isCurrentBook ? Color.accentColor : Color.clear,
                        lineWidth: 2
                    )
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: isCurrentBook)
        }
        .buttonStyle(.plain)
        .contextMenu {
            contextMenuItems
        }
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
    
    // MARK: - Book Cover Section
    private var bookCoverSection: some View {
        ZStack {
            // Cover Image - mit standardmäßigen Rounded Corners für Kompatibilität
            BookCoverView.square(
                book: book,
                size: 160,
                api: api,
                downloadManager: downloadManager,
                showProgress: true
            )

            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .mask(
                // Custom Mask für ungleichmäßige Ecken
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 16)
                        .frame(height: 160)
                    Rectangle()
                        .frame(height: 0)
                }
            )
            
            // Overlays
            VStack {
                HStack {
                    Spacer()
                    downloadStatusOverlay
                }
                .padding(.top, 8)
                .padding(.trailing, 8)
                
                Spacer()
                
                // Current book status indicator
                if isCurrentBook {
                    currentBookStatusOverlay
                        .padding(.bottom, 8)
                }
            }
        }
    }
    
    // MARK: - Download Status Overlay
    private var downloadStatusOverlay: some View {
        Group {
            if isDownloading {
                ZStack {
                    Circle()
                        .fill(.regularMaterial)
                        .frame(width: 32, height: 32)
                    
                    CircularProgressView(
                        progress: downloadProgress,
                        lineWidth: 2,
                        color: .accentColor
                    )
                    .frame(width: 24, height: 24)
                }
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
            } else if isDownloaded {
                ZStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
            } else {
                Button(action: startDownload) {
                    ZStack {
                        Circle()
                            .fill(.regularMaterial)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "arrow.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Current Book Status Overlay
    private var currentBookStatusOverlay: some View {
        HStack(spacing: 6) {
            Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
            
            Text(player.isPlaying ? "Spielt" : "Pausiert")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(.black.opacity(0.7))
        }
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Book Info Section
    private var bookInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(book.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Text(book.author ?? "Unbekannter Autor")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            // Progress indicator if available
            if isCurrentBook && player.duration > 0 {
                bookProgressIndicator
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Book Progress Indicator
    private var bookProgressIndicator: some View {
        VStack(spacing: 4) {
            ProgressView(value: player.currentTime, total: player.duration)
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                .scaleEffect(x: 1, y: 0.5)
            
            HStack {
                Text(TimeFormatter.formatTime(player.currentTime))
                Spacer()
                Text(TimeFormatter.formatDuration(player.duration))
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Context Menu
    private var contextMenuItems: some View {
        Group {
            Button(action: onTap) {
                Label("Abspielen", systemImage: "play.fill")
            }
            
            if !isDownloaded {
                Button(action: startDownload) {
                    Label("Herunterladen", systemImage: "arrow.down.circle")
                }
            } else {
                Button(role: .destructive, action: deleteDownload) {
                    Label("Download löschen", systemImage: "trash")
                }
            }
            
            Divider()
            
            Button(action: shareBook) {
                Label("Teilen", systemImage: "square.and.arrow.up")
            }
        }
    }
    
    // MARK: - Actions
    
    /// Start downloading the book
    private func startDownload() {
        Task {
            await downloadManager.downloadBook(book, api: api)
        }
    }
    
    /// Delete downloaded book
    private func deleteDownload() {
        downloadManager.deleteBook(book.id)
    }
    
    /// Share book (placeholder for future implementation)
    private func shareBook() {
        // Implementation for sharing book information
        print("[BookCard] Sharing book: \(book.title)")
    }
    
    // MARK: - Helper Methods
    
}

// MARK: - Circular Progress View
struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
    }
}
