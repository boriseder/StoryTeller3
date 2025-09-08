import SwiftUI

struct PlayerView: View {
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfAPI
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let book = player.book {
                    PlayerInterfaceView(book: book, player: player, api: api)
                } else {
                    emptyPlayerView
                }
            }
            .navigationTitle(player.book?.title ?? "Player")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var emptyPlayerView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Kein Buch ausgewählt")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("Wählen Sie ein Buch aus der Bibliothek")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlayerInterfaceView: View {
    let book: Book
    @ObservedObject var player: AudioPlayer
    let api: AudiobookshelfAPI
    
    var body: some View {
        VStack(spacing: 24) {
            coverSection
            chapterSection
            controlsSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                chapterSelectionMenu
            }
        }
    }
    
    private var chapterSelectionMenu: some View {
        Menu {
            ForEach(Array(book.chapters.enumerated()), id: \.offset) { index, chapter in
                Button(action: {
                    player.setCurrentChapter(index: index)
                }) {
                    HStack {
                        Text("\(chapter.title)")
                        Spacer()
                        if index == player.currentChapterIndex {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Kapitel", systemImage: "list.number")
        }
    }
    
    private var coverSection: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width * 0.8, 420)
            BookCoverView(
                book: book,
                api: api,
                downloadManager: player.downloadManagerReference,
                size: CGSize(width: size, height: size)
            )
            .frame(maxWidth: .infinity)
        }
        .frame(height: 300)
    }
    
    private var chapterSection: some View {
        VStack(spacing: 8) {
            Text(player.currentChapter?.title ?? "Unbekanntes Kapitel")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Text(book.author ?? "Unbekannter Autor")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            if book.chapters.count > 1 {
                Text("Kapitel \(player.currentChapterIndex + 1) von \(book.chapters.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var controlsSection: some View {
        VStack(spacing: 20) {
            progressSlider
            playbackControls
        }
    }
    
    private var progressSlider: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.duration, 1)
            )
            .tint(.accentColor)
            
            HStack {
                Text(TimeFormatter.formatTime(player.currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(TimeFormatter.formatDuration(player.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var playbackControls: some View {
        HStack(spacing: 40) {
            Button(action: player.previousChapter) {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
            }
            .disabled(player.currentChapterIndex == 0)
            
            Button(action: player.seek15SecondsBack) {
                Image(systemName: "gobackward.15")
                    .font(.title2)
            }
            
            Button(action: player.togglePlayPause) {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
            }
            
            Button(action: player.seek15SecondsForward) {
                Image(systemName: "goforward.15")
                    .font(.title2)
            }
            
            Button(action: player.nextChapter) {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
            }
            .disabled(player.currentChapterIndex >= book.chapters.count - 1)
        }
        .foregroundColor(.accentColor)
    }
    
}
