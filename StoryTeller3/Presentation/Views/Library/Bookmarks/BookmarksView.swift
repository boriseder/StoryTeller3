//
//  BookmarksView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 24.11.25.
//

import SwiftUI

// MARK: - All Bookmarks View
struct BookmarksView: View {
    @StateObject private var viewModel: BookmarkViewModel
    @EnvironmentObject var dependencies: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    init() {
        _viewModel = StateObject(wrappedValue: BookmarkViewModel())
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DSLayout.tightGap) {
                    if viewModel.groupByBook {
                        groupedView
                    } else {
                        flatView
                    }
                }
                .padding(.horizontal, DSLayout.screenPadding)
                .padding(.bottom, DSLayout.screenPadding)
            }
            .navigationTitle("Bookmarks")
            .searchable(text: $viewModel.searchText, prompt: "Search bookmarks...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        sortMenu
                        Divider()
                        groupingMenu
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .alert("Edit Bookmark", isPresented: .constant(viewModel.editingBookmark != nil)) {
                TextField("Bookmark name", text: $viewModel.editedBookmarkTitle)
                    .autocorrectionDisabled()
                
                Button("Cancel", role: .cancel) {
                    viewModel.cancelEditing()
                }
                
                Button("Save") {
                    viewModel.saveEditedBookmark()
                }
                .disabled(viewModel.editedBookmarkTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                Text("Enter a new name for this bookmark")
            }
        }
    }
    
    // MARK: - Flat View
    
    private var flatView: some View {
        ForEach(viewModel.allBookmarks) { enriched in
            EnrichedBookmarkRow(
                enriched: enriched,
                showBookInfo: true,
                onTap: { viewModel.jumpToBookmark(enriched, dismiss: dismiss) },
                onEdit: { viewModel.startEditingBookmark(enriched) },
                onDelete: { viewModel.deleteBookmark(enriched) }
            )
            .environmentObject(viewModel)
        }
    }
    
    // MARK: - Grouped View
    
    private var groupedView: some View {
        ForEach(Array(viewModel.groupedBookmarks.enumerated()), id: \.offset) { index, group in
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                // Section Header
                if let book = group.book {
                    BookSectionHeader(book: book, bookmarkCount: group.bookmarks.count)
                        .padding(.top, index == 0 ? 0 : DSLayout.contentGap)
                } else {
                    HStack(spacing: DSLayout.elementGap) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading book info...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(group.bookmarks.count) bookmark\(group.bookmarks.count == 1 ? "" : "s")")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, DSLayout.tightPadding)
                    .padding(.top, index == 0 ? 0 : DSLayout.contentGap)
                }
                
                // Bookmarks in group
                ForEach(group.bookmarks) { enriched in
                    EnrichedBookmarkRow(
                        enriched: enriched,
                        showBookInfo: false,
                        onTap: { viewModel.jumpToBookmark(enriched, dismiss: dismiss) },
                        onEdit: { viewModel.startEditingBookmark(enriched) },
                        onDelete: { viewModel.deleteBookmark(enriched) }
                    )
                    .environmentObject(viewModel)
                }
            }
        }
    }
    
    // MARK: - Sort Menu
    
    private var sortMenu: some View {
        Section("Sort By") {
            ForEach(BookmarkSortOption.allCases) { option in
                Button {
                    viewModel.sortOption = option
                } label: {
                    HStack {
                        Text(option.rawValue)
                        if viewModel.sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
    
    private var groupingMenu: some View {
        Section("View") {
            Button {
                viewModel.toggleGrouping()
            } label: {
                HStack {
                    Text(viewModel.groupByBook ? "Show All" : "Group by Book")
                    if viewModel.groupByBook {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }
}

// MARK: - Enriched Bookmark Row
struct EnrichedBookmarkRow: View {
    let enriched: EnrichedBookmark
    var showBookInfo: Bool = true
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var viewModel: BookmarkViewModel
    
    @State private var isPressed = false
    @State private var showDeleteConfirm = false
    
    var body: some View {
        HStack(spacing: DSLayout.contentGap) {
            // Orange bookmark icon
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
                Text(enriched.bookmark.title)
                    .font(DSText.emphasized)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: DSLayout.contentGap) {
                    HStack(spacing: DSLayout.tightGap) {
                        Image(systemName: "clock")
                            .font(DSText.metadata)
                        Text(enriched.bookmark.formattedTime)
                            .font(DSText.metadata)
                            .monospacedDigit()
                    }
                    .foregroundColor(.secondary)
                    
                    HStack(spacing: DSLayout.tightGap) {
                        Image(systemName: "calendar")
                            .font(DSText.metadata)
                        Text(enriched.bookmark.createdDate.formatted(date: .abbreviated, time: .omitted))
                            .font(DSText.metadata)
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Book Title (if showing)
                    if showBookInfo {
                        if enriched.isBookLoaded {
                            Text(enriched.bookTitle)
                                .font(DSText.metadata)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Loading...")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
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
                
                Button(action: { showDeleteConfirm = true }) {
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
        .alert("Delete Bookmark?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - Book Section Header
struct BookSectionHeader: View {
    let book: Book
    let bookmarkCount: Int
    
    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            Text(book.title)
                .font(.headline)
                .lineLimit(1)
            
            Spacer()
            
            Text("\(bookmarkCount) bookmark\(bookmarkCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, DSLayout.tightPadding)
    }
}
