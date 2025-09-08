import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfAPI?
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private let miniPlayerHeight: CGFloat = 64
    private let expandedPlayerHeight: CGFloat = 140
    
    var body: some View {
        VStack(spacing: 0) {
            if let book = player.book {
                miniPlayerContent(book: book)
                    .frame(height: isExpanded ? expandedPlayerHeight : miniPlayerHeight)
                    .background {
                        RoundedRectangle(cornerRadius: isExpanded ? 20 : 0)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
                    }
                    .clipped()
                    .offset(y: dragOffset)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
                    .animation(.spring(response: 0.3, dampingFraction: 0.9), value: dragOffset)
                    .gesture(dragGesture)
            }
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                }
                
                // Only allow downward dragging to dismiss
                let translation = max(0, value.translation.height)
                dragOffset = translation
            }
            .onEnded { value in
                isDragging = false
                
                // Dismiss threshold
                if value.translation.height > 80 {
                    // Hide mini player with animation
                    withAnimation(.easeInOut(duration: 0.3)) {
                        dragOffset = 200
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDismiss()
                        dragOffset = 0
                    }
                } else {
                    // Snap back
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }
    
    @ViewBuilder
    private func miniPlayerContent(book: Book) -> some View {
        VStack(spacing: 0) {
            // Main mini player row
            HStack(spacing: 12) {
                // Book cover
                bookCoverSection(book: book)
                
                // Book info
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Text(book.author ?? "Unbekannter Autor")
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                    
                    if let chapter = player.currentChapter {
                        Text(chapter.title)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                
                Spacer(minLength: 8)
                
                // Playback controls
                playbackControls
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                if !isExpanded {
                    onTap()
                }
            }
            
            // Expanded content
            if isExpanded {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
    }
    
    private func bookCoverSection(book: Book) -> some View {
        Group {
            if let api = api {
                BookCoverView.square(
                    book: book,
                    size: 48,
                    api: api,
                    downloadManager: player.downloadManagerReference
                )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "book.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var playbackControls: some View {
        HStack(spacing: 16) {
            // Previous chapter button
            Button(action: {
                player.previousChapter()
            }) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            }
            .disabled(player.currentChapterIndex == 0)
            
            // Play/Pause button
            Button(action: {
                player.togglePlayPause()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
            }
            
            // Next chapter button
            Button(action: {
                player.nextChapter()
            }) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            }
            .disabled(player.book == nil ||
                     player.currentChapterIndex >= (player.book?.chapters.count ?? 1) - 1)
        }
    }
    
    private var expandedContent: some View {
        VStack(spacing: 12) {
            // Progress bar
            progressSection
            
            // Additional controls
            HStack(spacing: 24) {
                // Speed control
                Button(action: {
                    cyclePlaybackSpeed()
                }) {
                    Text("\(player.playbackRate, specifier: "%.1f")x")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentColor)
                        .frame(width: 40, height: 24)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                // Seek back 15s
                Button(action: {
                    player.seek15SecondsBack()
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Seek forward 15s
                Button(action: {
                    player.seek15SecondsForward()
                }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
                
                // Expand to full player
                Button(action: onTap) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }
    
    private var progressSection: some View {
        VStack(spacing: 4) {
            // Progress bar
            ProgressView(value: player.currentTime, total: max(player.duration, 1))
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                .scaleEffect(x: 1, y: 0.8)
            
            // Time labels
            HStack {
                Text(TimeFormatter.formatTime(player.currentTime))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                
                Spacer()
                
                let remaining = max(0, player.duration - player.currentTime)
                Text("-\(TimeFormatter.formatTime(remaining))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Helper Methods
    
    private func cyclePlaybackSpeed() {
        let speeds: [Double] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
        let currentSpeed = Double(player.playbackRate)
        
        if let currentIndex = speeds.firstIndex(where: { abs($0 - currentSpeed) < 0.01 }) {
            let nextIndex = (currentIndex + 1) % speeds.count
            player.setPlaybackRate(speeds[nextIndex])
        } else {
            player.setPlaybackRate(1.0) // Default fallback
        }
    }
}
