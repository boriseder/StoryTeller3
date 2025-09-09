//
//  PlayerView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 09.09.25.
//

import SwiftUI
import AVKit

struct PlayerView: View {
    @StateObject private var viewModel: PlayerViewModel
    
    init(player: AudioPlayer, api: AudiobookshelfAPI) {
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
                SleepTimerView(player: viewModel.player)
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
            Text(viewModel.player.book?.title ?? "Kein Buch ausgewählt")
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
                    viewModel.showingChaptersList = true
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
                viewModel.player.previousChapter()
            }) {
                Image(systemName: "backward.end.fill")
                    .font(.title)
                    .foregroundColor(.primary)
            }
            .disabled(viewModel.player.currentChapterIndex == 0)
            
            // Rewind
            Button(action: {
                viewModel.player.seek15SecondsBack()
            }) {
                Image(systemName: "gobackward.15")
                    .font(.title)
                    .foregroundColor(.primary)
            }
            
            // Play/Pause
            Button(action: {
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
            
            // Fast Forward
            Button(action: {
                viewModel.player.seek15SecondsForward()
            }) {
                Image(systemName: "goforward.15")
                    .font(.title)
                    .foregroundColor(.primary)
            }
            
            // Next Chapter
            Button(action: {
                viewModel.player.nextChapter()
            }) {
                Image(systemName: "forward.end.fill")
                    .font(.title)
                    .foregroundColor(.primary)
            }
            .disabled(viewModel.player.book == nil || viewModel.player.currentChapterIndex >= (viewModel.player.book?.chapters.count ?? 1) - 1)
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
        // Simulator: Mock-Button mit Debug-Menü
        Menu {
            Button("iPhone Speaker") {
                AppLogger.debug.debug("Selected: iPhone Speaker")
            }
            Button("Bluetooth Headphones (Simulator)") {
                AppLogger.debug.debug("Selected: Bluetooth Headphones")
            }
            Button("AirPlay Device (Simulator)") {
                AppLogger.debug.debug("Selected: AirPlay Device")
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
                viewModel.showingPlaybackSettings = true
            }) {
                Label("Playback Settings", systemImage: "gearshape")
            }
            
            Button(action: {
                viewModel.showingSleepTimer = true
            }) {
                Label("Sleep Timer", systemImage: "moon")
            }
            
            Button(action: {
                viewModel.player.pause()
            }) {
                Label("Stop Playback", systemImage: "stop")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }
}
