//
//  SupportingPlayerViews.swift
//  StoryTeller3
//
//  Created by Boris Eder on 09.09.25.
//

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
