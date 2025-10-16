import SwiftUI
import AVKit

// MARK: - Optimized Chapters List View
struct OptimizedChaptersListView: View {
    let player: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    
    @State private var chapterVMs: [ChapterStateViewModel] = []
    @State private var updateTimer: Timer?
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
                                headerSection(book: book)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                                    .padding(.bottom, 16)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(chapterVMs) { chapterVM in
                                        OptimizedChapterCardView(
                                            viewModel: chapterVM,
                                            onTap: {
                                                handleChapterTap(index: chapterVM.id)
                                            }
                                        )
                                        .id(chapterVM.id)
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
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                BookCoverView.square(
                    book: book,
                    size: 60,
                    api: nil,
                    downloadManager: player.downloadManagerReference
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
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

// MARK: - Optimized Chapter Card View
struct OptimizedChapterCardView: View {
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
    
    var body: some View {
        Button(action: {
            AppLogger.general.debug("[ChapterCard] Chapter \(viewModel.id) tapped: \(viewModel.chapter.title)")
            onTap()
        }) {
            HStack(spacing: 16) {
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
                        .frame(width: 48, height: 48)
                    
                    if viewModel.isCurrent && viewModel.isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .symbolEffect(.variableColor.iterative, options: .repeating, value: viewModel.isPlaying)
                    } else {
                        Text("\(viewModel.id + 1)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(viewModel.isCurrent ? .white : .secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.chapter.title)
                        .font(.subheadline)
                        .fontWeight(viewModel.isCurrent ? .semibold : .regular)
                        .foregroundColor(viewModel.isCurrent ? .primary : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 12) {
                        if let start = viewModel.chapter.start {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(TimeFormatter.formatTime(start))
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if let start = viewModel.chapter.start, let end = viewModel.chapter.end {
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
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: viewModel.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                                .symbolEffect(.pulse, options: .repeating, value: viewModel.isPlaying)
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
