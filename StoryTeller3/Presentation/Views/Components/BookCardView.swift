import SwiftUI

// MARK: - BookCard Style
enum BookCardStyle {
    case library
    case series
    case compact
    
    var coverSize: CGFloat {
        switch self {
        case .library: return 152
        case .series: return 152
        case .compact: return 80
        }
    }
    
    var cardPadding: CGFloat {
        switch self {
        case .library: return 8
        case .series: return 8
        case .compact: return 8
        }
    }
    
    var textPadding: CGFloat {
        switch self {
        case .library: return 8
        case .series: return 8
        case .compact: return 4
        }
    }
    
    var dimensions: (width: CGFloat, height: CGFloat, infoHeight: CGFloat) {
        let cardWidth = coverSize + (cardPadding * 2)
        let cardHeight = cardWidth * 1.45 // 40% höher als breit
        let infoHeight: CGFloat = cardHeight - coverSize - (cardPadding * 3)
        
        return (width: cardWidth, height: cardHeight, infoHeight: infoHeight)
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .library: return 8
        case .series: return 8
        case .compact: return 4
        }
    }
    
    var titleFont: Font {
        switch self {
        case .library: return .system(size: 16, weight: .semibold, design: .rounded)
        case .series: return .system(size: 12, weight: .semibold, design: .rounded)
        case .compact: return .system(size: 10, weight: .semibold, design: .rounded)
        }
    }
    
    var authorFont: Font {
        switch self {
        case .library: return .system(size: 12, weight: .medium)
        case .series: return .system(size: 10, weight: .medium)
        case .compact: return .system(size: 9, weight: .medium)
        }
    }
}

struct BookCardView: View {
    // MARK: - Properties
    let book: Book
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfAPI?
    @ObservedObject var downloadManager: DownloadManager
    let onTap: () -> Void
    let style: BookCardStyle
    
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
    
    private var dimensions: (width: CGFloat, height: CGFloat, infoHeight: CGFloat) {
        style.dimensions
    }
    
    // MARK: - Initializers
    init(
        book: Book,
        player: AudioPlayer,
        api: AudiobookshelfAPI?,
        downloadManager: DownloadManager,
        style: BookCardStyle = .library,
        onTap: @escaping () -> Void
    ) {
        self.book = book
        self.player = player
        self.api = api
        self.downloadManager = downloadManager
        self.style = style
        self.onTap = onTap
    }
    
    // MARK: - Body
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    bookCoverSection
                    Spacer()
                }
                .padding(.top, style.cardPadding)
                
                Spacer()
                
                bookInfoSection
                    .frame(height: dimensions.infoHeight)
                    .padding(.bottom, style.cardPadding)
                    .padding(.horizontal, style.cardPadding)
            }
            .frame(width: dimensions.width, height: dimensions.height)
            .background {
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(.ultraThinMaterial)
                    .shadow(
                        color: .black.opacity(0.1),
                        radius: isPressed ? 4 : 12,
                        x: 0,
                        y: isPressed ? 2 : 6
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: style.cornerRadius)
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
        .padding(.trailing, DSLayout.elementPadding)
    }
    
    // MARK: - Book Cover Section
    private var bookCoverSection: some View {
        ZStack {
            BookCoverView.square(
                book: book,
                size: style.coverSize,
                api: api,
                downloadManager: downloadManager,
                showProgress: true
            )
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
            
            // Overlays
            VStack {
                HStack {
                    // ← NEU: Series Badge (top-left)
                    if book.isCollapsedSeries && style == .library {
                        seriesBadge
                    }
                    
                    Spacer()
                    
                    // Download Status (top-right)
                    if style == .library {
                        downloadStatusOverlay
                    }
                }
                .padding(.top, style == .library ? 8 : 4)
                .padding(.horizontal, style == .library ? 8 : 4)
                
                Spacer()
                
                if isCurrentBook && style == .library {
                    currentBookStatusOverlay
                        .padding(.bottom, 8)
                }
            }
        }
        .frame(width: style.coverSize, height: style.coverSize)
    }
    
    // MARK: - ← NEU: Series Badge
    private var seriesBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 10))
            Text("\(book.seriesBookCount)")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background {
            Capsule()
                .fill(.blue)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
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
                
            } else if api != nil { // Nur anzeigen wenn API verfügbar
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
        VStack(alignment: .leading, spacing: 0) {
            // ← GEÄNDERT: Verwende displayTitle für Series
            Text(book.displayTitle)
                .font(style.titleFont)
                .foregroundColor(.primary)
                .lineLimit(style == .compact ? 1 : 2)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: style == .compact ? 2 : 4) {
                Text(book.author ?? "Unbekannter Autor")
                    .font(style.authorFont)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Progress indicator nur für library style
                if isCurrentBook && player.duration > 0 && style == .library {
                    bookProgressIndicator
                }
            }
        }
        .padding(.horizontal, style.textPadding)
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
                if book.isCollapsedSeries {
                    Label("Serie anzeigen", systemImage: "books.vertical.fill")
                } else {
                    Label("Abspielen", systemImage: "play.fill")
                }
            }
            
            if !isDownloaded && style == .library && api != nil {
                Button(action: startDownload) {
                    if book.isCollapsedSeries {
                        Label("Serie herunterladen", systemImage: "arrow.down.circle")
                    } else {
                        Label("Herunterladen", systemImage: "arrow.down.circle")
                    }
                }
            } else if isDownloaded && style == .library {
                Button(role: .destructive, action: deleteDownload) {
                    Label("Download löschen", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Actions
    
    private func startDownload() {
        guard let api = api else {
            AppLogger.debug.debug("[BookCard] Cannot download: API not available")
            return
        }
        
        Task {
            await downloadManager.downloadBook(book, api: api)
        }
    }

    private func deleteDownload() {
        downloadManager.deleteBook(book.id)
    }
    
    private func shareBook() {
        AppLogger.debug.debug("[BookCard] Sharing book: \(book.title)")
    }
}

// MARK: - Convenience Extensions
extension BookCardView {
    // Convenience initializers für verschiedene Styles
    static func library(
        book: Book,
        player: AudioPlayer,
        api: AudiobookshelfAPI?,
        downloadManager: DownloadManager,
        onTap: @escaping () -> Void
    ) -> BookCardView {
        BookCardView(
            book: book,
            player: player,
            api: api,
            downloadManager: downloadManager,
            style: .library,
            onTap: onTap
        )
    }
    
    static func series(
        book: Book,
        player: AudioPlayer,
        api: AudiobookshelfAPI?,
        downloadManager: DownloadManager,
        onTap: @escaping () -> Void
    ) -> BookCardView {
        BookCardView(
            book: book,
            player: player,
            api: api,
            downloadManager: downloadManager,
            style: .series,
            onTap: onTap
        )
    }
    
    static func compact(
        book: Book,
        player: AudioPlayer,
        api: AudiobookshelfAPI?,
        downloadManager: DownloadManager,
        onTap: @escaping () -> Void
    ) -> BookCardView {
        BookCardView(
            book: book,
            player: player,
            api: api,
            downloadManager: downloadManager,
            style: .compact,
            onTap: onTap
        )
    }
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
