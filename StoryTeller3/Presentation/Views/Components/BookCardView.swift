import SwiftUI

// MARK: - BookCard Style
enum BookCardStyle {
    case library
    case series
    
    var coverSize: CGFloat {
        switch self {
        case .library: return 150
        case .series: return 150
        }
    }
    
    var dimensions: (width: CGFloat, height: CGFloat, infoHeight: CGFloat) {
        let cardWidth = coverSize + (DSLayout.elementPadding * 2)
        let cardHeight = cardWidth * 1.40// 40% höher als breit
        let infoHeight: CGFloat = cardHeight - coverSize - 3 * DSLayout.elementPadding
        
        /*
        AppLogger.ui.info("### coverSize: \(coverSize)")
        AppLogger.ui.info("### cardWidth: \(cardWidth)")
        AppLogger.ui.info("### cardHeight: \(cardHeight)")
        AppLogger.ui.info("### infoHeight: \(infoHeight)")
        */
          
        return (width: cardWidth, height: cardHeight, infoHeight: infoHeight)
    }
}


// MARK: - Book Card View
struct BookCardView: View {
    let viewModel: BookCardStateViewModel
    let api: AudiobookshelfAPI?
    let onTap: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void
    let style: BookCardStyle
    
    @State private var isPressed = false
    
    private var dimensions: (width: CGFloat, height: CGFloat, infoHeight: CGFloat) {
        style.dimensions
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    bookCoverSection
                    Spacer()
                }
                .padding(.top, DSLayout.elementPadding)
                
                Spacer()
                bookInfoSection
                    .frame(height: dimensions.infoHeight)
                    .padding(.bottom, DSLayout.elementPadding)
                    .padding(.horizontal, DSLayout.elementPadding)
            }
            .frame(width: dimensions.width, height: dimensions.height)
            .background {
                RoundedRectangle(cornerRadius: DSCorners.element)
                    .fill(.regularMaterial)
                    .shadow(
                        color: .black.opacity(0.1),
                        radius: isPressed ? 4 : 12,
                        x: 0,
                        y: isPressed ? 2 : 6
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: DSCorners.element)
                    .stroke(
                        viewModel.isCurrentBook ? Color.accentColor : Color.clear,
                        lineWidth: 2
                    )
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isCurrentBook)
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
            BookCoverView.square(
                book: viewModel.book,
                size: style.coverSize,
                api: api,
                downloadManager: nil,
                showProgress: false
            )
            .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
            
            VStack {
                HStack {
                    if viewModel.book.isCollapsedSeries && style == .library {
                        seriesBadge
                    }
                    
                    Spacer()
                    
                    if style == .library {
                        downloadStatusOverlay
                    }
                }
                .padding(.top, style == .library ? 8 : 4)
                .padding(.horizontal, style == .library ? 8 : 4)
                
                Spacer()
                
                if viewModel.isCurrentBook && style == .library {
                    currentBookStatusOverlay
                        .padding(.bottom, 8)
                }
            }
        }
        .frame(width: style.coverSize, height: style.coverSize)
    }
    
    private var seriesBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 10))
            Text("\(viewModel.book.seriesBookCount)")
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
    
    private var downloadStatusOverlay: some View {
        Group {
            if viewModel.isDownloading {
                downloadingOverlay
            } else if viewModel.isDownloaded {
                downloadedBadge
            } else if api != nil {
                downloadButton
            }
        }
    }
    
    private var downloadingOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .trim(from: 0, to: viewModel.downloadProgress)
                        .stroke(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(viewModel.downloadProgress * 100))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 2) {
                    Text("\(Int(viewModel.downloadProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if let status = viewModel.downloadStatus {
                        Text(status)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: style.coverSize - 20)
                
                Button(action: onDelete) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                        Text("Cancel")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.8))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
        .frame(width: style.coverSize, height: style.coverSize)
    }
    
    private var downloadedBadge: some View {
        VStack {
            HStack {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(.ultraThickMaterial)
                        .frame(width: 32, height: 32)

                    
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                }
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                .padding(DSLayout.tightPadding)
            }
            
            Spacer()
        }
    }
    
    private var downloadButton: some View {
        VStack {
            HStack {
                Spacer()
                
                Button(action: onDownload) {
                    ZStack {
                        Circle()
                            .fill(.ultraThickMaterial)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "icloud.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.accentColor)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(DSLayout.tightPadding)
            }
            
            Spacer()
        }
    }
    
    private var currentBookStatusOverlay: some View {
        HStack(spacing: 6) {
            Image(systemName: viewModel.isPlaying ? "speaker.wave.2.fill" : "pause.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
            
            Text(viewModel.isPlaying ? "Spielt" : "Pausiert")
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
    
    private var bookInfoSection: some View {
        VStack(alignment: .leading) {
            
            // Text soll in zwei Zeilen sein
            Text(viewModel.book.displayTitle)
                .font(DSText.emphasized)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                //.frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()

            VStack(alignment: .leading) {
                Text(viewModel.book.author ?? "Unbekannter Autor")
                    .font(DSText.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if viewModel.isCurrentBook && viewModel.duration > 0 && style == .library {
                    bookProgressIndicator
                }
            }
        }
       // .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var bookProgressIndicator: some View {
        VStack(spacing: 4) {
            ProgressView(value: viewModel.currentProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                .scaleEffect(x: 1, y: 0.5)
            
            HStack {
                Text(TimeFormatter.formatTime(viewModel.currentTime))
                Spacer()
                Text(TimeFormatter.formatDuration(viewModel.duration))
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
    }
    
    private var contextMenuItems: some View {
        Group {
            Button(action: onTap) {
                if viewModel.book.isCollapsedSeries {
                    Label("Serie anzeigen", systemImage: "books.vertical.fill")
                } else {
                    Label("Abspielen", systemImage: "play.fill")
                }
            }
            
            if !viewModel.isDownloaded && style == .library && api != nil {
                Button(action: onDownload) {
                    if viewModel.book.isCollapsedSeries {
                        Label("Serie herunterladen", systemImage: "arrow.down.circle")
                    } else {
                        Label("Herunterladen", systemImage: "arrow.down.circle")
                    }
                }
            } else if viewModel.isDownloaded && style == .library {
                Button(role: .destructive, action: onDelete) {
                    Label("Download löschen", systemImage: "trash")
                }
            }
        }
    }
}
