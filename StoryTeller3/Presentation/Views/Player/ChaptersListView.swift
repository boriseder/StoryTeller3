import SwiftUI
import AVKit

// MARK: - Tab Selection Enum
enum ChapterViewTab {
    case chapters
    case bookmarks
}

struct ChaptersListView: View {
    let player: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: ChapterViewTab = .chapters
    @State private var chapterVMs: [ChapterStateViewModel] = []
    @State private var updateTimer: Timer?
    @State private var scrollTarget: Int?
    
    // Bookmark states
    @State private var bookmarks: [Bookmark] = []
    @State private var editingBookmark: Bookmark?
    @State private var editedBookmarkTitle = ""
    @State private var showingDeleteConfirm: Bookmark?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                if let book = player.book {
                    headerSection(book: book)
                        .padding(.horizontal, DSLayout.screenPadding)
                        .padding(.top, DSLayout.elementPadding)
                        .padding(.bottom, DSLayout.tightGap)
                }
                
                // Segmented Control
                Picker("View", selection: $selectedTab) {
                    Text("Chapters").tag(ChapterViewTab.chapters)
                    Text("Bookmarks").tag(ChapterViewTab.bookmarks)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DSLayout.screenPadding)
                .padding(.bottom, DSLayout.contentGap)
                
                // Content
                if selectedTab == .chapters {
                    chaptersListView
                } else {
                    bookmarksListView
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(selectedTab == .chapters ? "Chapters" : "Bookmarks")
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
                loadBookmarks()
                startPeriodicUpdates()
            }
            .onDisappear {
                stopPeriodicUpdates()
            }
            .alert("Edit Bookmark", isPresented: .constant(editingBookmark != nil)) {
                TextField("Bookmark name", text: $editedBookmarkTitle)
                    .autocorrectionDisabled()
                
                Button("Cancel", role: .cancel) {
                    editingBookmark = nil
                    editedBookmarkTitle = ""
                }
                
                Button("Save") {
                    saveEditedBookmark()
                }
                .disabled(editedBookmarkTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                Text("Enter a new name for this bookmark")
            }
            .alert("Delete Bookmark?", isPresented: .constant(showingDeleteConfirm != nil)) {
                Button("Cancel", role: .cancel) {
                    showingDeleteConfirm = nil
                }
                
                Button("Delete", role: .destructive) {
                    if let bookmark = showingDeleteConfirm {
                        deleteBookmark(bookmark)
                    }
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Header Section
    
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
                
                VStack(alignment: .leading, spacing: DSLayout.elementGap) {
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
                    
                    if selectedTab == .chapters {
                        HStack {
                            Image(systemName: "list.number")
                                .font(DSText.button)
                                .foregroundColor(.secondary)
                            Text("\(book.chapters.count) chapters")
                                .font(DSText.detail)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "waveform")
                                .font(DSText.button)
                                .foregroundColor(.secondary)
                            Text("Current chapter \(player.currentChapterIndex + 1)")
                                .font(DSText.detail)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Image(systemName: "bookmark.fill")
                                .font(DSText.button)
                                .foregroundColor(.secondary)
                            Text("\(bookmarks.count) bookmarks")
                                .font(DSText.detail)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(DSLayout.contentPadding)
    }
    
    // MARK: - Chapters List View
    
    private var chaptersListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DSLayout.tightGap) {
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
    
    // MARK: - Bookmarks List View
    
    private var bookmarksListView: some View {
        ScrollView {
            if bookmarks.isEmpty {
                VStack(spacing: DSLayout.contentGap) {
                    Image(systemName: "bookmark.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No bookmarks yet")
                        .font(DSText.emphasized)
                        .foregroundColor(.secondary)
                    
                    Text("Add bookmarks from the player controls")
                        .font(DSText.detail)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: DSLayout.tightGap) {
                    ForEach(bookmarks) { bookmark in
                        BookmarkCardView(
                            bookmark: bookmark,
                            onTap: {
                                jumpToBookmark(bookmark)
                            },
                            onEdit: {
                                startEditingBookmark(bookmark)
                            },
                            onDelete: {
                                showingDeleteConfirm = bookmark
                            }
                        )
                    }
                }
                .padding(.horizontal, DSLayout.screenPadding)
                .padding(.bottom, DSLayout.screenPadding)
            }
        }
    }
    
    // MARK: - Chapter Actions
    
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
    
    // MARK: - Bookmark Actions
    
    private func loadBookmarks() {
        guard let book = player.book else { return }
        bookmarks = BookmarkRepository.shared.getBookmarks(for: book.id)
            .sorted { $0.time < $1.time }
    }
    
    private func jumpToBookmark(_ bookmark: Bookmark) {
        player.jumpToBookmark(bookmark)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
    
    private func startEditingBookmark(_ bookmark: Bookmark) {
        editingBookmark = bookmark
        editedBookmarkTitle = bookmark.title
    }
    
    private func saveEditedBookmark() {
        guard let bookmark = editingBookmark,
              let book = player.book else { return }
        
        let newTitle = editedBookmarkTitle.trimmingCharacters(in: .whitespaces)
        guard !newTitle.isEmpty else { return }
        
        Task {
            do {
                try await BookmarkRepository.shared.updateBookmark(
                    libraryItemId: book.id,
                    time: bookmark.time,
                    newTitle: newTitle
                )
                
                await MainActor.run {
                    loadBookmarks()
                    editingBookmark = nil
                    editedBookmarkTitle = ""
                }
            } catch {
                AppLogger.general.error("[ChaptersList] Failed to update bookmark: \(error)")
            }
        }
    }
    
    private func deleteBookmark(_ bookmark: Bookmark) {
        guard let book = player.book else { return }
        
        Task {
            do {
                try await BookmarkRepository.shared.deleteBookmark(
                    libraryItemId: book.id,
                    time: bookmark.time
                )
                
                await MainActor.run {
                    loadBookmarks()
                    showingDeleteConfirm = nil
                }
            } catch {
                AppLogger.general.error("[ChaptersList] Failed to delete bookmark: \(error)")
            }
        }
    }
}

// MARK: - Bookmark Card View

struct BookmarkCardView: View {
    let bookmark: Bookmark
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: DSLayout.contentGap) {
            // Bookmark icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.orange.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: DSLayout.largeIcon, height: DSLayout.largeIcon)
                
                Image(systemName: "bookmark.fill")
                    .font(DSText.button)
                    .foregroundColor(.white)
            }
            .padding(.leading, DSLayout.elementPadding)
            
            // Bookmark info
            VStack(alignment: .leading, spacing: DSLayout.elementGap) {
                Text(bookmark.title)
                    .font(DSText.emphasized)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: DSLayout.contentGap) {
                    HStack(spacing: DSLayout.tightGap) {
                        Image(systemName: "clock")
                            .font(DSText.metadata)
                        Text(bookmark.formattedTime)
                            .font(DSText.metadata)
                            .monospacedDigit()
                    }
                    .foregroundColor(.secondary)
                    
                    HStack(spacing: DSLayout.tightGap) {
                        Image(systemName: "calendar")
                            .font(DSText.metadata)
                        Text(bookmark.createdDate.formatted(date: .abbreviated, time: .omitted))
                            .font(DSText.metadata)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: DSLayout.tightGap) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, DSLayout.elementPadding)
        }
        .padding(DSLayout.elementPadding)
        .background(
            RoundedRectangle(cornerRadius: DSCorners.element)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: isPressed ? 4 : 8,
                    x: 0,
                    y: isPressed ? 2 : 4
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeIn(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.1)) {
                    isPressed = false
                }
                onTap()
            }
        }
    }
}

// MARK: - Chapter Card View (Existing)

struct ChapterCardView: View {
    let viewModel: ChapterStateViewModel
    let onTap: () -> Void
    
    @State private var isPressed = false
            
    var body: some View {
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
                    .frame(width: DSLayout.largeIcon, height: DSLayout.largeIcon)
                
                if viewModel.isCurrent && viewModel.isPlaying {
                    Image(systemName: "waveform")
                        .font(DSText.button)
                        .foregroundColor(.white)
                        .symbolEffect(.variableColor.iterative, options: .repeating, value: viewModel.isPlaying)
                } else {
                    Text("\(viewModel.id + 1)")
                        .font(DSText.button)
                        .foregroundColor(viewModel.isCurrent ? .white : .secondary)
                }
            }
            .padding(.leading, DSLayout.elementPadding)
            
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
                            .frame(width: DSLayout.largeIcon, height: DSLayout.largeIcon)
                        
                        Image(systemName: viewModel.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                            .font(DSText.button)
                            .foregroundColor(.accentColor)
                            .symbolEffect(.pulse, options: .repeating, value: viewModel.isPlaying)
                    }
                }
            }
            .padding(.trailing, DSLayout.elementPadding)
        }
        .padding(DSLayout.elementPadding)
        .background(
            RoundedRectangle(cornerRadius: DSCorners.element)
                .fill(viewModel.isCurrent ? Color.accentColor.opacity(0.08) : Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: DSCorners.element)
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
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
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
}
