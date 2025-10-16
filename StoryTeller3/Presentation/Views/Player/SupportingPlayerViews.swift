import SwiftUI
import AVKit

// MARK: - AVRoutePickerView Wrapper
struct AVRoutePickerViewWrapper: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.backgroundColor = UIColor.clear
        routePickerView.tintColor = UIColor.systemBlue
        return routePickerView
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

// MARK: - Chapters List View
struct ChaptersListView: View {
    let player: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var scrollTarget: Int?
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                    
                    ScrollView {
                        if let book = player.book {
                            VStack(spacing: 0) {
                                // Header Section
                                headerSection(book: book)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                                    .padding(.bottom, 16)
                                
                                // Chapters List
                                LazyVStack(spacing: 12) {
                                    ForEach(Array(book.chapters.enumerated()), id: \.offset) { index, chapter in
                                        ChapterCardView(
                                            chapter: chapter,
                                            chapterIndex: index,
                                            currentChapterIndex: player.currentChapterIndex,
                                            isPlaying: player.isPlaying,
                                            currentTime: player.currentTime,
                                            onTap: {
                                                handleChapterTap(index: index)
                                            }
                                        )
                                        .id(index)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Chapters")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
                .onAppear {
                    scrollTarget = player.currentChapterIndex
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(player.currentChapterIndex, anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    private func headerSection(book: Book) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Book Cover
                BookCoverView.square(
                    book: book,
                    size: 60,
                    api: nil,
                    downloadManager: player.downloadManagerReference
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                // Book Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    if let author = book.author {
                        Text(author)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            
            // Stats Row
            HStack(spacing: 16) {
                statsItem(
                    icon: "list.number",
                    text: "\(book.chapters.count) chapters"
                )
                
                Divider()
                    .frame(height: 12)
                
                statsItem(
                    icon: "waveform",
                    text: "Chapter \(player.currentChapterIndex + 1)"
                )
                
                Spacer()
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func statsItem(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
        }
    }
    
    private func handleChapterTap(index: Int) {
        AppLogger.general.debug("[ChaptersList] Chapter \(index) selected")
        
        let wasPlaying = player.isPlaying
        
        withAnimation(.easeInOut(duration: 0.2)) {
            scrollTarget = index
        }
        
        player.setCurrentChapter(index: index)
        
        if wasPlaying {
            player.play()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
}

// MARK: - Chapter Card View
struct ChapterCardView: View {
    let chapter: Chapter
    let chapterIndex: Int
    let currentChapterIndex: Int
    let isPlaying: Bool
    let currentTime: Double
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private var isCurrentChapter: Bool {
        chapterIndex == currentChapterIndex
    }
    
    private var chapterProgress: Double {
        guard isCurrentChapter,
              let start = chapter.start,
              let end = chapter.end,
              end > start else {
            return 0
        }
        
        let chapterDuration = end - start
        let chapterCurrentTime = max(0, min(currentTime - start, chapterDuration))
        return chapterCurrentTime / chapterDuration
    }
    
    var body: some View {
        Button(action: {
            AppLogger.general.debug("[ChapterCard] Chapter \(chapterIndex) tapped: \(chapter.title)")
            onTap()
        }) {
            HStack(spacing: 16) {
                // Chapter Number Circle
                ZStack {
                    Circle()
                        .fill(
                            isCurrentChapter ?
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.secondary.opacity(0.2), Color.secondary.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    if isCurrentChapter && isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .symbolEffect(.variableColor.iterative, options: .repeating, value: isPlaying)
                    } else {
                        Text("\(chapterIndex + 1)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(isCurrentChapter ? .white : .secondary)
                    }
                }
                
                // Chapter Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(chapter.title)
                        .font(.subheadline)
                        .fontWeight(isCurrentChapter ? .semibold : .regular)
                        .foregroundColor(isCurrentChapter ? .primary : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 12) {
                        if let start = chapter.start {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(TimeFormatter.formatTime(start))
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if let start = chapter.start, let end = chapter.end {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.caption2)
                                Text(TimeFormatter.formatTime(end - start))
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    // Progress bar for current chapter
                    if isCurrentChapter && chapterProgress > 0 {
                        ProgressView(value: chapterProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                            .scaleEffect(x: 1, y: 0.6)
                    }
                }
                
                Spacer()
                
                // Status Indicator
                VStack {
                    if isCurrentChapter {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                                .symbolEffect(.pulse, options: .repeating, value: isPlaying)
                        }
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrentChapter ? Color.accentColor.opacity(0.08) : Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isCurrentChapter ? Color.accentColor.opacity(0.3) : Color.clear,
                                lineWidth: 1.5
                            )
                    )
                    .shadow(
                        color: isCurrentChapter ? Color.accentColor.opacity(0.1) : Color.black.opacity(0.05),
                        radius: isPressed ? 4 : 8,
                        x: 0,
                        y: isPressed ? 2 : 4
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
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
}

// MARK: - Chapter Row View (Legacy - keeping for compatibility)
struct ChapterRowView: View {
    let chapter: Chapter
    let chapterIndex: Int
    let currentChapterIndex: Int
    let onTap: () -> Void
    
    private var isCurrentChapter: Bool {
        chapterIndex == currentChapterIndex
    }
    
    var body: some View {
        Button(action: {
            AppLogger.general.debug("[ChapterRow] Chapter \(chapterIndex) tapped: \(chapter.title)")
            onTap()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chapter.title)
                        .font(.subheadline)
                        .fontWeight(isCurrentChapter ? .semibold : .regular)
                        .foregroundColor(isCurrentChapter ? .accentColor : .primary)
                        .multilineTextAlignment(.leading)
                    
                    if let start = chapter.start {
                        Text(TimeFormatter.formatTime(start))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isCurrentChapter {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Playback Settings View
struct PlaybackSettingsView: View {
    @ObservedObject var player: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    
    private let playbackRateOptions: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                playbackSpeedSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("Playback Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var playbackSpeedSection: some View {
        VStack(spacing: 16) {
            Text("Playback Speed")
                .font(.headline)
            
            VStack(spacing: 12) {
                Text("\(player.playbackRate, specifier: "%.2f")x")
                    .font(.title)
                    .fontWeight(.bold)
                    .monospacedDigit()
                
                Slider(
                    value: Binding(
                        get: { Double(player.playbackRate) },
                        set: { newValue in
                            AppLogger.general.debug("[PlaybackSettings] Speed changed to: \(newValue)x")
                            player.setPlaybackRate(newValue)
                        }
                    ),
                    in: 0.5...2.0,
                    step: 0.05
                ) { editing in
                    if !editing {
                        // Ensure rate is applied when slider interaction ends
                        if player.isPlaying {
                            // The player will automatically apply the rate when playing
                            // No need to access private player property
                        }
                        AppLogger.general.debug("[PlaybackSettings] Speed slider interaction ended, rate applied: \(player.playbackRate)")
                    }
                }
                .accentColor(.primary)
                
                HStack {
                    Text("0.5x")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("2.0x")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Quick Speed Buttons
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(playbackRateOptions, id: \.self) { rate in
                    Button(action: {
                        AppLogger.general.debug("[PlaybackSettings] Quick speed button: \(rate)x")
                        player.setPlaybackRate(rate)
                    }) {
                        Text("\(rate, specifier: rate.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f")x")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(abs(Double(player.playbackRate) - rate) < 0.01 ? Color.accentColor : Color.gray.opacity(0.2))
                            )
                            .foregroundColor(abs(Double(player.playbackRate) - rate) < 0.01 ? .white : .primary)
                    }
                }
            }
        }
    }
}
