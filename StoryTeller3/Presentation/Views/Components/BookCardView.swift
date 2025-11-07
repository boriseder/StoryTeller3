import SwiftUI

// MARK: - Design System Constants

// MARK: - BookCard Style
enum BookCardStyle {
    case library
    case series
    
    var coverSize: CGFloat {
        switch self {
        case .library: return DSLayout.cardCoverNoPadding
        case .series: return DSLayout.cardCoverNoPadding
        }
    }
    
    var dimensions: (width: CGFloat, height: CGFloat, infoHeight: CGFloat) {
        let cardWidth = coverSize
        let cardHeight = cardWidth * 1.30
        let infoHeight = cardHeight - coverSize - 3 * DSLayout.elementPadding
                  
        return (width: cardWidth, height: cardHeight, infoHeight: infoHeight)
    }
}

// MARK: - Book Card View
struct BookCardView: View {
    let viewModel: BookCardStateViewModel
    let api: AudiobookshelfClient?
    let onTap: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void
    let style: BookCardStyle
    
    @State private var isPressed = false
    @EnvironmentObject var theme: ThemeManager

    private var dimensions: (width: CGFloat, height: CGFloat, infoHeight: CGFloat) {
        style.dimensions
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: DSLayout.elementPadding) {
                bookCoverSection
                
                bookInfoSection
                    .padding(.bottom, DSLayout.elementPadding)

            }
            .frame(width: dimensions.width, height: dimensions.height)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isCurrentBook)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
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
    
    // MARK: - Book Cover Section (Modern Overlays)

    private var bookCoverSection: some View {
        ZStack {
            // Base Cover
            BookCoverView.square(
                book: viewModel.book,
                size: style.coverSize,
                api: api,
                downloadManager: nil,
                showProgress: false
            )
            .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
            
            // Bottom: Reading/Listening Progress (2px)
            if viewModel.duration > 0 {
                VStack {
                    Spacer()
                    bookProgressIndicator
                }
            }

            // Top Layer: Series Badge & Download Status
            VStack {
                HStack(alignment: .top) {
                    // Top Left: Series Badge
                    // if viewModel.book.isCollapsedSeries && style == .library && !viewModel.isDownloading {
                    if viewModel.book.isCollapsedSeries && style == .library && !viewModel.isDownloading {
                        seriesBadge
                            .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    // Top Right: Download Status Layer (Button / Progress / Downloaded)
                    //if style == .library  {
                        downloadStatusView
                            .transition(.scale.combined(with: .opacity))
                    //}
                }
                .padding(DSLayout.elementPadding)

                Spacer()

                // Bottom Center: Play/Pause Overlay
                if viewModel.isCurrentBook && style == .library && !viewModel.isDownloading {
                    currentBookStatusOverlay
                        .padding(.bottom, DSLayout.elementPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(width: style.coverSize, height: style.coverSize)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.isDownloading)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.isCurrentBook)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.isDownloaded)
    }


    // MARK: - Info Section

    private var bookInfoSection: some View {
        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
            Text(viewModel.book.displayTitle)
                .font(DSText.detail)
                .foregroundColor(theme.textColor)
                .lineLimit(1)
                .frame(maxWidth: dimensions.width - 2 * DSLayout.elementPadding, alignment: .leading)
                .fixedSize(horizontal: true, vertical: true)


            if style == .library {
                VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                    Text(viewModel.book.author ?? "Unknown Author")
                        .font(DSText.metadata)
                        .foregroundColor(theme.textColor.opacity(0.85))
                        .lineLimit(1)
                    
                    if viewModel.isCurrentBook && viewModel.duration > 0 && style == .library {
                        bookProgressIndicator
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, DSLayout.elementPadding)

    }


    // MARK: - Download Status Layer (Top Right, komplett gekoppelt)
    
    private var downloadStatusView: some View {
        ZStack {
            // Hintergrundkreis
            Circle()
                .fill(.white.opacity(0.95))
                .frame(width: DSLayout.actionButtonSize, height: DSLayout.actionButtonSize)
                .shadow(color: .black.opacity(DSLayout.shadowOpacity),
                        radius: 6, x: 0, y: 2)

            // Fortschrittsring (nur sichtbar beim Download)
            if viewModel.isDownloading {
                Circle()
                    .trim(from: 0, to: viewModel.downloadProgress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.accentColor, .accentColor.opacity(0.8)]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: DSLayout.actionButtonSize, height: DSLayout.actionButtonSize)
                    .animation(.linear(duration: 0.2), value: viewModel.downloadProgress)
            }

            // Symbol je nach Zustand
            Image(systemName: {
                if viewModel.isDownloading {
                    "arrow.down.circle"
                } else if viewModel.isDownloaded {
                    "checkmark.circle.fill"
                } else {
                    "icloud.and.arrow.down"
                }
            }())
            .symbolRenderingMode(.hierarchical)
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .foregroundStyle(viewModel.isDownloaded ? .green : Color.black)
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.25), value: viewModel.isDownloading)
            .animation(.easeInOut(duration: 0.25), value: viewModel.isDownloaded)
        }
        .onTapGesture {
            if viewModel.isDownloaded {
                onDelete()
            } else if !viewModel.isDownloading {
                onDownload()
            }
        }
    }
    
    // MARK: - Series Badge
    
    private var seriesBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Text("\(viewModel.book.seriesBookCount)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(LinearGradient(colors: [.blue.opacity(0.85), .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 2)
        .scaleEffect(1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.book.seriesBookCount)
    }

    
    // MARK: - Play/Pause Overlay
    
    private var currentBookStatusOverlay: some View {
        HStack(spacing: 6) {
            Image(systemName: viewModel.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .if(viewModel.isPlaying) { view in
                    view.symbolEffect(.pulse, options: .repeating, value: viewModel.isPlaying)
                }
            
            Text(viewModel.isPlaying ? "Läuft" : "Pausiert")
                .font(.caption)
                .foregroundColor(.white)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(
                    viewModel.isPlaying ?
                    AnyShapeStyle(LinearGradient(colors: [.accentColor.opacity(0.8), .accentColor.opacity(0.6)],
                                                startPoint: .leading, endPoint: .trailing)) :
                    AnyShapeStyle(Color.primary.opacity(0.7))
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 2)
        .scaleEffect(viewModel.isPlaying ? 1.05 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.isPlaying)
    }

    
    // MARK: - Reading/Listening Progress Bar
    
    private var bookProgressIndicator: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 2)
                
                Capsule()
                    .fill(LinearGradient(colors: [.accentColor, .accentColor.opacity(0.8)],
                                         startPoint: .leading,
                                         endPoint: .trailing))
                    .frame(width: geometry.size.width * viewModel.currentProgress, height: 2)
                    .animation(.linear(duration: 0.2), value: viewModel.currentProgress)
            }
        }
        .frame(height: 2)
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }

    
    // MARK: - Context Menu
    private var contextMenuItems: some View {
        Group {
            Button(action: onTap) {
                if viewModel.book.isCollapsedSeries {
                    Label("Show series", systemImage: "books.vertical.fill")
                } else {
                    Label("Play", systemImage: "play.fill")
                }
            }
            Divider()
            if !viewModel.isDownloaded && api != nil {
                Button(action: onDownload) {
                    if viewModel.book.isCollapsedSeries {
                        Label("Download series", systemImage: "arrow.down.circle")
                    } else {
                        Label("Download book", systemImage: "arrow.down.circle")
                    }
                }
            } else if viewModel.isDownloaded {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete download", systemImage: "trash")
                }
            }
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

enum BookStatus {
    case downloaded
    case streamable
    case unavailable
}
