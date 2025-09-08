import SwiftUI
import AVKit

struct PlayerView: View {
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfAPI
    
    @State private var showingChaptersList = false
    @State private var showingSleepTimer = false
    @State private var showingPlaybackSettings = false
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Cover Art Section
                    coverArtSection
                        .frame(height: geometry.size.height * 0.5)
                    
                    // Controls Section
                    controlsSection
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    moreButton
                }
            }
            .sheet(isPresented: $showingChaptersList) {
                ChaptersListView(player: player)
            }
            .sheet(isPresented: $showingSleepTimer) {
                SleepTimerView()
            }
            .sheet(isPresented: $showingPlaybackSettings) {
                PlaybackSettingsView(player: player)
            }
        }
        .onAppear {
            sliderValue = player.currentTime
        }
        .onReceive(player.$currentTime) { time in
            if !isDraggingSlider {
                sliderValue = time
            }
        }
    }
    
    // MARK: - Cover Art Section
    private var coverArtSection: some View {
        VStack(spacing: 20) {
            Spacer()
            
            if let book = player.book {
                BookCoverView.square(
                    book: book,
                    size: 300,
                    api: api,
                    downloadManager: player.downloadManagerReference
                )
                .shadow(radius: 12)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .overlay(
                        Image(systemName: "book.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    )
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Controls Section
    private var controlsSection: some View {
        VStack(spacing: 24) {
            // Track Info
            trackInfoSection
            
            // Progress
            progressSection
            
            // Main Controls
            mainControlsSection
            
            // Secondary Controls
            secondaryControlsSection
            
            Spacer()
        }
    }
    
    private var trackInfoSection: some View {
        VStack(spacing: 8) {
            Text(player.book?.title ?? "Kein Buch ausgewählt")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Text(player.book?.author ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
            
            if let chapter = player.currentChapter {
                Button(action: {
                    showingChaptersList = true
                }) {
                    HStack {
                        Image(systemName: "list.bullet")
                            .font(.caption)
                        Text(chapter.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 8) {
            // Progress Slider
            Slider(
                value: Binding(
                    get: { sliderValue },
                    set: { newValue in
                        sliderValue = newValue
                        if !isDraggingSlider {
                            player.seek(to: newValue)
                        }
                    }
                ),
                in: 0...max(player.duration, 1)
            ) { editing in
                isDraggingSlider = editing
                if !editing {
                    player.seek(to: sliderValue)
                }
            }
            .accentColor(.primary)
            
            // Time Labels
            HStack {
                Text(TimeFormatter.formatTime(player.currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                
                Spacer()
                
                let remaining = max(0, player.duration - player.currentTime)
                Text("-\(TimeFormatter.formatTime(remaining))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }
    
    private var mainControlsSection: some View {
        HStack(spacing: 32) {
            // Previous Chapter
            Button(action: {
                player.previousChapter()
            }) {
                Image(systemName: "backward.end.fill")
                    .font(.title)
                    .foregroundColor(.primary)
            }
            .disabled(player.currentChapterIndex == 0)
            
            // Rewind
            Button(action: {
                player.seek15SecondsBack()
            }) {
                Image(systemName: "gobackward.15")
                    .font(.title)
                    .foregroundColor(.primary)
            }
            
            // Play/Pause
            Button(action: {
                player.togglePlayPause()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            
            // Fast Forward
            Button(action: {
                player.seek15SecondsForward()
            }) {
                Image(systemName: "goforward.15")
                    .font(.title)
                    .foregroundColor(.primary)
            }
            
            // Next Chapter
            Button(action: {
                player.nextChapter()
            }) {
                Image(systemName: "forward.end.fill")
                    .font(.title)
                    .foregroundColor(.primary)
            }
            .disabled(player.book == nil || player.currentChapterIndex >= (player.book?.chapters.count ?? 1) - 1)
        }
    }
    
    private var secondaryControlsSection: some View {
        HStack(spacing: 40) {
            // Playback Speed
            speedButton
            
            // Sleep Timer
            sleepTimerButton
            
            // Audio Route
            audioRouteButton
            
            // Chapters
            chaptersButton
        }
        .foregroundColor(.primary)
    }
    
    private var speedButton: some View {
        Button(action: {
            showingPlaybackSettings = true
        }) {
            VStack(spacing: 4) {
                Text("\(player.playbackRate, specifier: "%.1f")x")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("Speed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var sleepTimerButton: some View {
        Button(action: {
            showingSleepTimer = true
        }) {
            VStack(spacing: 4) {
                Image(systemName: "moon")
                    .font(.title3)
                Text("Sleep")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var audioRouteButton: some View {
        #if targetEnvironment(simulator)
        // Simulator: Mock-Button mit Debug-Menü
        Menu {
            Button("iPhone Speaker") {
                print("Selected: iPhone Speaker")
            }
            Button("Bluetooth Headphones (Simulator)") {
                print("Selected: Bluetooth Headphones")
            }
            Button("AirPlay Device (Simulator)") {
                print("Selected: AirPlay Device")
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "speaker.fill")
                    .font(.title3)
                Text("Audio")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        #else
        // Echtes Gerät: Echter AVRoutePickerView
        VStack(spacing: 4) {
            AVRoutePickerViewWrapper()
                .frame(width: 20, height: 20)
            Text("Audio")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        #endif
    }
    
    private var chaptersButton: some View {
        Button(action: {
            showingChaptersList = true
        }) {
            VStack(spacing: 4) {
                Image(systemName: "list.bullet")
                    .font(.title3)
                Text("Chapters")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .disabled(player.book == nil)
    }
    
    private var moreButton: some View {
        Menu {
            Button(action: {
                showingPlaybackSettings = true
            }) {
                Label("Playback Settings", systemImage: "gearshape")
            }
            
            Button(action: {
                showingSleepTimer = true
            }) {
                Label("Sleep Timer", systemImage: "moon")
            }
            
            Button(action: {
                player.pause()
            }) {
                Label("Stop Playback", systemImage: "stop")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }
}

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
    
    var body: some View {
        NavigationView {
            List {
                if let book = player.book {
                    ForEach(Array(book.chapters.enumerated()), id: \.offset) { index, chapter in
                        ChapterRowView(
                            chapter: chapter,
                            chapterIndex: index,
                            currentChapterIndex: player.currentChapterIndex,
                            onTap: {
                                player.setCurrentChapter(index: index)
                                dismiss()
                            }
                        )
                    }
                }
            }
            .navigationTitle("Chapters")
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
}

// MARK: - Chapter Row View
struct ChapterRowView: View {
    let chapter: Chapter
    let chapterIndex: Int
    let currentChapterIndex: Int
    let onTap: () -> Void
    
    private var isCurrentChapter: Bool {
        chapterIndex == currentChapterIndex
    }
    
    var body: some View {
        Button(action: onTap) {
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

// MARK: - Sleep Timer View
struct SleepTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMinutes: Int = 30
    @State private var isTimerActive = false
    @State private var remainingTime: TimeInterval = 0
    @State private var timer: Timer? // ✅ Timer gehört in SleepTimerView!
    
    private let timerOptions = [5, 10, 15, 30, 45, 60, 90, 120]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if isTimerActive {
                    activeSleepTimerView
                } else {
                    sleepTimerOptionsView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        // ✅ MEMORY LEAK FIX - Timer cleanup
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            timer?.invalidate()
            timer = nil
        }
    }
    
    private var activeSleepTimerView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Sleep Timer Active")
                    .font(.headline)
                
                Text(TimeFormatter.formatTime(remainingTime))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            
            Button("Cancel Timer") {
                cancelTimer()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
    
    private var sleepTimerOptionsView: some View {
        VStack(spacing: 16) {
            Text("Set Sleep Timer")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(timerOptions, id: \.self) { minutes in
                    Button(action: {
                        startTimer(minutes: minutes)
                    }) {
                        VStack(spacing: 4) {
                            Text("\(minutes)")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text(minutes == 1 ? "minute" : "minutes")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
    
    private func startTimer(minutes: Int) {
        remainingTime = TimeInterval(minutes * 60)
        isTimerActive = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            remainingTime -= 1
            
            if remainingTime <= 0 {
                // Timer finished - would pause playback here
                cancelTimer()
                dismiss()
            }
        }
    }
    
    private func cancelTimer() {
        timer?.invalidate()
        timer = nil
        isTimerActive = false
        remainingTime = 0
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
                        set: { player.setPlaybackRate($0) }
                    ),
                    in: 0.5...2.0,
                    step: 0.05
                )
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
