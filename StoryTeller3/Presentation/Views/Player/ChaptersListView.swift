import SwiftUI
import AVKit

struct ChaptersListView: View {
    let player: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    
    @State private var chapterVMs: [ChapterStateViewModel] = []
    @State private var updateTimer: Timer?
    @State private var scrollTarget: Int?
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ZStack {
                    ScrollView {
                        if let book = player.book {
                            VStack(spacing: 0) {
                                headerSection(book: book)
                                    .padding(.horizontal, DSLayout.screenPadding)
                                    .padding(.top, 8)
                                    .padding(.bottom, DSLayout.comfortPadding)
                                
                                LazyVStack(spacing: DSLayout.contentGap) {
                                    ForEach(chapterVMs) { chapterVM in
                                        ChapterCardView(
                                            viewModel: chapterVM,
                                            onTap: {
                                                handleChapterTap(index: chapterVM.id)
                                            }
                                        )
                                        .id(chapterVM.id)
                                    }
                                }
                                .padding(.horizontal, DSLayout.screenPadding)
                                .padding(.bottom, DSLayout.screenPadding)
                            }
                        }
                    }
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Chapters")
                            .font(DSText.emphasized)
                            .foregroundColor(.primary)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: DSLayout.icon))
                        }
                    }
                }
                .onAppear {
                    updateChapterViewModels()
                    startPeriodicUpdates()
                    scrollTarget = player.currentChapterIndex
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(player.currentChapterIndex, anchor: .center)
                        }
                    }
                }
                .onDisappear {
                    stopPeriodicUpdates()
                }
            }
        }
    }
    
    private func headerSection(book: Book) -> some View {
        
        VStack(spacing: DSLayout.contentGap) {
            HStack(spacing: DSLayout.contentGap) {
                BookCoverView.square(
                    book: book,
                    size: DSLayout.avatar,
                    api: nil,
                    downloadManager: player.downloadManagerReference
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(DSText.emphasized)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    if let author = book.author {
                        Text(author)
                            .font(DSText.detail)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: DSLayout.contentGap) {
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
            .font(DSText.detail)
            .foregroundColor(.secondary)
        }
        .padding(DSLayout.contentPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func statsItem(icon: String, text: String) -> some View {
        HStack(spacing: DSLayout.tightGap) {
            Image(systemName: icon)
                .font(DSText.button)
            Text(text)
        }
    }
    
    private func updateChapterViewModels() {
        guard let book = player.book else { return }
        
        let newVMs = book.chapters.enumerated().map { index, chapter in
            ChapterStateViewModel(
                index: index,
                chapter: chapter,
                player: player
            )
        }
        
        if chapterVMs != newVMs {
            chapterVMs = newVMs
        }
    }
    
    private func startPeriodicUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateChapterViewModels()
        }
    }
    
    private func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func handleChapterTap(index: Int) {
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

struct ChapterCardView: View {
    let viewModel: ChapterStateViewModel
    let onTap: () -> Void
    
    @State private var isPressed = false
        
    private var chapterProgress: Double {
        guard viewModel.isCurrent,
              let start = viewModel.chapter.start,
              let end = viewModel.chapter.end,
              end > start else {
            return 0
        }
        
        let chapterDuration = end - start
        let chapterCurrentTime = max(0, min(viewModel.currentTime - start, chapterDuration))
        return chapterCurrentTime / chapterDuration
    }
    
    private func truncateChapterTitle(_ title: String, maxLength: Int = 40) -> String {
        guard title.count > maxLength else { return title }
        
        let visibleCount = maxLength - 3
        let headCount = visibleCount / 2
        let tailCount = visibleCount - headCount
        
        let head = title.prefix(headCount)
        let tail = title.suffix(tailCount)
        
        return "\(head)...\(tail)"
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSLayout.contentGap) {
                ZStack {
                    Circle()
                        .fill(
                            viewModel.isCurrent ?
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
                        .frame(width: DSLayout.avatar, height: DSLayout.avatar)
                    
                    if viewModel.isCurrent && viewModel.isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: DSLayout.avatar * 0.375, weight: .semibold))
                            .foregroundColor(.white)
                            .symbolEffect(.variableColor.iterative, options: .repeating, value: viewModel.isPlaying)
                    } else {
                        Text("\(viewModel.id + 1)")
                            .font(.system(size: DSLayout.avatar * 0.333, weight: .bold, design: .rounded))
                            .foregroundColor(viewModel.isCurrent ? .white : .secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: DSLayout.elementGap) {
                    Text(truncateChapterTitle(viewModel.chapter.title))
                        .font(DSText.emphasized)
                        .fontWeight(viewModel.isCurrent ? .semibold : .regular)
                        .foregroundColor(viewModel.isCurrent ? .primary : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: DSLayout.contentGap) {
                        if let start = viewModel.chapter.start {
                            HStack(spacing: DSLayout.tightGap) {
                                Image(systemName: "clock")
                                    .font(DSText.metadata)
                                Text(TimeFormatter.formatTime(start))
                                    .font(DSText.metadata)
                                    .monospacedDigit()
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if let start = viewModel.chapter.start, let end = viewModel.chapter.end {
                            HStack(spacing: DSLayout.tightGap) {
                                Image(systemName: "timer")
                                    .font(DSText.metadata)
                                Text(TimeFormatter.formatTime(end - start))
                                    .font(DSText.metadata)
                                    .monospacedDigit()
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    if viewModel.isCurrent && chapterProgress > 0 {
                        ProgressView(value: chapterProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                            .scaleEffect(x: 1, y: 0.6)
                    }
                }
                
                Spacer()
                
                VStack {
                    if viewModel.isCurrent {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: DSLayout.largeIcon,
                                       height: DSLayout.largeIcon)
                            
                            Image(systemName: viewModel.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                                .font(DSText.button)
                                .foregroundColor(.accentColor)
                                .symbolEffect(.pulse, options: .repeating, value: viewModel.isPlaying)
                        }
                    } else {
                        Image(systemName: "chevron.right")
                            .font(DSText.button)
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }
            .padding(DSLayout.contentPadding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(viewModel.isCurrent ? Color.accentColor.opacity(0.08) : Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                viewModel.isCurrent ? Color.accentColor.opacity(0.3) : Color.clear,
                                lineWidth: 1.5
                            )
                    )
                    .shadow(
                        color: viewModel.isCurrent ? Color.accentColor.opacity(0.1) : Color.black.opacity(0.05),
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
