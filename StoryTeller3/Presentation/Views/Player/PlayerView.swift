import SwiftUI
import AVKit

struct PlayerView: View {
    @StateObject private var viewModel: PlayerViewModel
    @EnvironmentObject private var sleepTimer: SleepTimerService  // ADD THIS


    init(player: AudioPlayer, api: AudiobookshelfClient) {
        self._viewModel = StateObject(wrappedValue: PlayerViewModel(
            player: player,
            api: api
        ))
    }

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
            .sheet(isPresented: $viewModel.showingChaptersList) {
                ChaptersListView(player: viewModel.player)
            }
            .sheet(isPresented: $viewModel.showingSleepTimer) {
                SleepTimerView()
                    .environmentObject(sleepTimer)
            }
            .sheet(isPresented: $viewModel.showingPlaybackSettings) {
                PlaybackSettingsView(player: viewModel.player)
            }
        }
        .onAppear {
            viewModel.sliderValue = viewModel.player.currentTime
        }
        .onReceive(viewModel.player.$currentTime) { time in
            viewModel.updateSliderFromPlayer(time)
        }
    }
    
    // MARK: - Cover Art Section
    private var coverArtSection: some View {
        VStack(spacing: 20) {
            Spacer()
            
            if let book = viewModel.player.book {
                BookCoverView.square(
                    book: book,
                    size: 300,
                    api: viewModel.api,
                    downloadManager: viewModel.player.downloadManagerReference
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
            Text(viewModel.player.book?.title ?? "No book selected")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Text(viewModel.player.book?.author ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
            
            if let chapter = viewModel.player.currentChapter {
                Button(action: {
                    AppLogger.general.debug("[PlayerView] Chapter button tapped - showing chapters list")
                    viewModel.showingChaptersList = true
                }) {
                    HStack {
                        Image(systemName: "list.bullet")
                            .font(.caption)
                        Text(chapter.title)
                            .font(.caption)
                            .truncationMode(.middle)
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
                    get: { viewModel.sliderValue },
                    set: { viewModel.updateSliderValue($0) }
                ),
                in: 0...max(viewModel.player.duration, 1)
            ) { editing in
                viewModel.onSliderEditingChanged(editing)
            }
            .accentColor(.primary)
            
            // Time Labels
            HStack {
                Text(TimeFormatter.formatTime(viewModel.player.currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                
                Spacer()
                
                let remaining = max(0, viewModel.player.duration - viewModel.player.currentTime)
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
                AppLogger.general.debug("[PlayerView] Previous chapter button tapped")
                viewModel.player.previousChapter()
            }) {
                Image(systemName: "backward.end.fill")
                    .font(.title)
                    .foregroundColor(isFirstChapter ? .secondary : .primary)
            }
            .disabled(isFirstChapter)
            
            // Rewind 15s
            Button(action: {
                AppLogger.general.debug("[PlayerView] Rewind 15s button tapped")
                viewModel.player.seek15SecondsBack()
            }) {
                Image(systemName: "gobackward.15")
                    .font(.title)
                    .foregroundColor(.primary)
            }
            
            // Play/Pause
            Button(action: {
                AppLogger.general.debug("[PlayerView] Play/pause button tapped - currently playing: \(viewModel.player.isPlaying)")
                viewModel.player.togglePlayPause()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: viewModel.player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            
            // Fast Forward 15s
            Button(action: {
                AppLogger.general.debug("[PlayerView] Fast forward 15s button tapped")
                viewModel.player.seek15SecondsForward()
            }) {
                Image(systemName: "goforward.15")
                    .font(.title)
                    .foregroundColor(.primary)
            }
            
            // Next Chapter
            Button(action: {
                AppLogger.general.debug("[PlayerView] Next chapter button tapped")
                viewModel.player.nextChapter()
            }) {
                Image(systemName: "forward.end.fill")
                    .font(.title)
                    .foregroundColor(isLastChapter ? .secondary : .primary)
            }
            .disabled(isLastChapter)
        }
    }
    
    // MARK: - Computed Properties for Button States
    private var isFirstChapter: Bool {
        viewModel.player.currentChapterIndex == 0
    }
    
    private var isLastChapter: Bool {
        guard let book = viewModel.player.book else { return true }
        return viewModel.player.currentChapterIndex >= book.chapters.count - 1
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
            AppLogger.general.debug("[PlayerView] Speed button tapped - showing playback settings")
            viewModel.showingPlaybackSettings = true
        }) {
            VStack(spacing: 4) {
                Text("\(viewModel.player.playbackRate, specifier: "%.1f")x")
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
            AppLogger.general.debug("[PlayerView] Sleep timer button tapped")
            viewModel.showingSleepTimer = true
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
        // Simulator: Mock button with debug menu
        Menu {
            Button("iPhone Speaker") {
                AppLogger.general.debug("[PlayerView] Selected: iPhone Speaker")
            }
            Button("Bluetooth Headphones (Simulator)") {
                AppLogger.general.debug("[PlayerView] Selected: Bluetooth Headphones")
            }
            Button("AirPlay Device (Simulator)") {
                AppLogger.general.debug("[PlayerView] Selected: AirPlay Device")
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
        // Real device: Actual AVRoutePickerView
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
            AppLogger.general.debug("[PlayerView] Chapters button tapped")
            viewModel.showingChaptersList = true
        }) {
            VStack(spacing: 4) {
                Image(systemName: "list.bullet")
                    .font(.title3)
                Text("Chapters")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .disabled(viewModel.player.book == nil)
    }
    
    private var moreButton: some View {
        Menu {
            Button(action: {
                AppLogger.general.debug("[PlayerView] More menu - playback settings")
                viewModel.showingPlaybackSettings = true
            }) {
                Label("Playback Settings", systemImage: "gearshape")
            }
            
            Button(action: {
                AppLogger.general.debug("[PlayerView] More menu - sleep timer")
                viewModel.showingSleepTimer = true
            }) {
                Label("Sleep Timer", systemImage: "moon")
            }
            
            Button(action: {
                AppLogger.general.debug("[PlayerView] More menu - stop playback")
                viewModel.player.pause()
            }) {
                Label("Stop Playback", systemImage: "stop")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }
}
