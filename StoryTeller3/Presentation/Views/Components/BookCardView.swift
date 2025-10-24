import SwiftUI

// MARK: - Design System Constants
enum CardOverlayDesign {
    static let badgeCornerRadius: CGFloat = 12
    static let actionButtonSize: CGFloat = 36
    static let statusHeight: CGFloat = 28
    static let padding: CGFloat = 8
    static let shadowRadius: CGFloat = 8
    static let shadowOpacity: CGFloat = 0.15
}

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
        let cardHeight = cardWidth * 1.40
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
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                bookCoverSection
                
                if style == .series {
                    Text(viewModel.book.displayTitle)
                        .font(DSText.metadata)
                        .foregroundColor(theme.textColor)
                        .lineLimit(1)
                        .frame(maxWidth: dimensions.width - 2 * DSLayout.elementPadding, alignment: .leading)
                        .fixedSize(horizontal: true, vertical: true)
                        .padding(.vertical, DSLayout.elementPadding)
                        .padding(.horizontal, DSLayout.elementPadding)
                } else {
                    Spacer()
                    bookInfoSection
                        .padding(.bottom, DSLayout.elementPadding)
                }
            }
            .frame(width: dimensions.width, height: dimensions.height)
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
                    if viewModel.book.isCollapsedSeries && style == .library && !viewModel.isDownloading {
                        seriesBadge
                            .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    // Top Right: Download Status Layer (Button / Progress / Downloaded)
                    if style == .library {
                        downloadStatusView
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(CardOverlayDesign.padding)

                Spacer()

                // Bottom Center: Play/Pause Overlay
                if viewModel.isCurrentBook && style == .library && !viewModel.isDownloading {
                    currentBookStatusOverlay
                        .padding(.bottom, CardOverlayDesign.padding)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.book.displayTitle)
                .font(.subheadline)
                .foregroundColor(theme.textColor)
                .lineLimit(1)
                .frame(maxWidth: style.coverSize, alignment: .leading)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.book.author ?? "Unbekannter Autor")
                    .font(.caption2)
                    .foregroundColor(theme.textColor.opacity(0.7))
                    .lineLimit(1)

                if viewModel.isCurrentBook && viewModel.duration > 0 && style == .library {
                    bookProgressIndicator
                }
            }
        }
    }


    // MARK: - Download Status Layer (Top Right, komplett gekoppelt)
    private var downloadStatusView: some View {
        ZStack {
            // 1️⃣ Idle Download Button
            if !viewModel.isDownloading && !viewModel.isDownloaded {
                Button(action: onDownload) {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: CardOverlayDesign.actionButtonSize,
                               height: CardOverlayDesign.actionButtonSize)
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .overlay(
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(LinearGradient(
                                    colors: [.accentColor, .accentColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing)
                                )
                        )
                        .shadow(color: .black.opacity(CardOverlayDesign.shadowOpacity), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            // 2️⃣ Morphender Download-Ring
            if viewModel.isDownloading {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: CardOverlayDesign.actionButtonSize,
                               height: CardOverlayDesign.actionButtonSize)

                    Circle()
                        .trim(from: 0, to: viewModel.downloadProgress)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.accentColor, .accentColor.opacity(0.6)]),
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: CardOverlayDesign.actionButtonSize,
                               height: CardOverlayDesign.actionButtonSize)
                        .animation(.linear(duration: 0.2), value: viewModel.downloadProgress)

                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
                .transition(.scale.combined(with: .opacity))
            }

            // 3️⃣ Downloaded Badge
            if viewModel.isDownloaded {
                Circle()
                    .fill(LinearGradient(
                        colors: [.green.opacity(0.85), .green],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing)
                    )
                    .frame(width: CardOverlayDesign.actionButtonSize,
                           height: CardOverlayDesign.actionButtonSize)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 2)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: CardOverlayDesign.actionButtonSize,
               height: CardOverlayDesign.actionButtonSize)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.isDownloading)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.isDownloaded)
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
