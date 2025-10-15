import SwiftUI

struct DownloadsView: View {
    @StateObject private var viewModel: DownloadsViewModel
    @EnvironmentObject private var appConfig: AppConfig
    @EnvironmentObject private var appState: AppStateManager
    
    @State private var showingStorageInfo = false
    
    init(downloadManager: DownloadManager, player: AudioPlayer, api: AudiobookshelfAPI, appState: AppStateManager, onBookSelected: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: DownloadsViewModelFactory.create(
            downloadManager: downloadManager,
            player: player,
            api: api,
            appState: appState,
            onBookSelected: onBookSelected
        ))
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 132, maximum: 160), spacing: 16)
    ]
    
    var body: some View {
            Group {
                if viewModel.downloadedBooks.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(
                appConfig.userBackgroundStyle.textColor == .white ? .dark : .light,
                for: .navigationBar
            )            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarButtons
                }
            }
            .alert("Delete book", isPresented: $viewModel.showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    viewModel.cancelDelete()
                }
                Button("Delete", role: .destructive) {
                    viewModel.confirmDeleteBook()
                }
            } message: {
                if let book = viewModel.bookToDelete {
                    Text("Are you sure? '\(book.title)' will be deleted.")
                }
            }
            .sheet(isPresented: $showingStorageInfo) {
                storageInfoSheet
            }
            .alert("Error", isPresented: $viewModel.showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        StateContainer {
            VStack(spacing: 32) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 80))
                    .foregroundStyle(.orange.gradient)
                    .frame(width: 80, height: 80)
                
                VStack(spacing: 8) {
                    Text("No Downloads")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Download books to listen offline. Look for the download button on book cards.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Downloads are stored on this device only")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Downloaded books work without internet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Content View
    private var contentView: some View {
        ZStack {
            DynamicBackground()
            
            // Storage info banner
            if viewModel.showStorageWarning {
                storageWarningBanner
            }
            
            // Downloads grid
            ScrollView {
                LazyVStack(spacing: DSLayout.contentGap) {
                    // Statistics card
                    downloadStatsCard
                    
                    // Books grid
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.downloadedBooks) { book in
                            BookCardView(
                                book: book,
                                player: viewModel.player,
                                api: viewModel.api,
                                downloadManager: viewModel.downloadManager,
                                style: .library,
                                onTap: {
                                    Task {
                                        await viewModel.playBook(book)
                                    }
                                }
                            )
                        }
                    }
                    
                    Spacer()
                        .frame(height: DSLayout.miniPlayerHeight)
                }
            }
            .padding(.horizontal, DSLayout.screenPadding)
        }
    }
    
    // MARK: - Storage Warning Banner
    private var storageWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Low Storage")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Less than \(viewModel.formatBytes(viewModel.storageThreshold)) available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                showingStorageInfo = true
            }) {
                Text("Manage")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.1))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.orange.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    // MARK: - Download Stats Card
    private var downloadStatsCard: some View {
        VStack(spacing: DSLayout.elementGap) {
            HStack {
                VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                    Text("Downloaded Books")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(viewModel.downloadedBooks.count) books available offline")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showingStorageInfo = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
            }
            
            Divider()
            
            HStack(spacing: DSLayout.contentGap) {
                StatItem(
                    icon: "externaldrive.fill",
                    title: "Storage Used",
                    value: viewModel.formatBytes(viewModel.totalStorageUsed),
                    color: .blue
                )
                
                Divider()
                    .frame(height: 40)
                
                StatItem(
                    icon: "externaldrive.badge.checkmark",
                    title: "Available",
                    value: viewModel.formatBytes(viewModel.availableStorage),
                    color: viewModel.availableStorage < viewModel.storageThreshold ? .orange : .green
                )
            }
        }
        .padding(DSLayout.contentGap)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Toolbar Buttons
    private var toolbarButtons: some View {
        HStack(spacing: 12) {
            if !viewModel.downloadedBooks.isEmpty {
                Button(action: {
                    showingStorageInfo = true
                }) {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
            }
            
            Button(action: {
                NotificationCenter.default.post(name: .init("ShowSettings"), object: nil)
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Storage Info Sheet
    private var storageInfoSheet: some View {
        NavigationStack {
            List {
                // Storage overview section
                Section {
                    StorageRow(
                        title: "Total Storage Used",
                        value: viewModel.formatBytes(viewModel.totalStorageUsed),
                        icon: "externaldrive.fill",
                        color: .blue
                    )
                    
                    StorageRow(
                        title: "Available Storage",
                        value: viewModel.formatBytes(viewModel.availableStorage),
                        icon: "externaldrive.badge.checkmark",
                        color: viewModel.availableStorage < viewModel.storageThreshold ? .orange : .green
                    )
                    
                    StorageRow(
                        title: "Downloaded Books",
                        value: "\(viewModel.downloadedBooks.count)",
                        icon: "books.vertical.fill",
                        color: .purple
                    )
                } header: {
                    Label("Storage Overview", systemImage: "chart.pie.fill")
                }
                
                // Storage tips section
                Section {
                    TipRow(
                        icon: "lightbulb.fill",
                        title: "Manage Storage",
                        description: "Delete books you've finished to free up space"
                    )
                    
                    TipRow(
                        icon: "wifi",
                        title: "Stream Instead",
                        description: "Use streaming when online to save storage"
                    )
                    
                    TipRow(
                        icon: "arrow.down.circle",
                        title: "Selective Downloads",
                        description: "Only download books you plan to listen to offline"
                    )
                } header: {
                    Label("Storage Tips", systemImage: "info.circle")
                }
                
                // Per-book storage section
                if !viewModel.downloadedBooks.isEmpty {
                    Section {
                        ForEach(viewModel.downloadedBooks) { book in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    
                                    if let author = book.author {
                                        Text(author)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(viewModel.getBookStorageSize(book))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    Button(action: {
                                        viewModel.requestDeleteBook(book)
                                        showingStorageInfo = false
                                    }) {
                                        Text("Delete")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    } header: {
                        Label("Downloaded Books", systemImage: "arrow.down.circle.fill")
                    }
                }
                
                // Danger zone section
                if !viewModel.downloadedBooks.isEmpty {
                    Section {
                        Button(role: .destructive, action: {
                            viewModel.showingDeleteAllConfirmation = true
                            showingStorageInfo = false
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Delete All Downloads")
                            }
                        }
                    } header: {
                        Label("Danger Zone", systemImage: "exclamationmark.triangle")
                    } footer: {
                        Text("This will permanently delete all downloaded books. You can re-download them anytime when online.")
                    }
                }
            }
            .navigationTitle("Storage Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingStorageInfo = false
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            Image(systemName: icon)
                .font(.system(size: DSLayout.icon))
                .foregroundColor(color)
                .frame(width: DSLayout.largeIcon, height: DSLayout.largeIcon)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

struct StorageRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
    }
}

struct TipRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

