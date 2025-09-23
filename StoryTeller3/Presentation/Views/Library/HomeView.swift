//
//  HomeView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 10.09.25.
//


//
//  HomeView.swift
//  StoryTeller3
//
//  Created by Assistant on 10.09.25
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    
    init(player: AudioPlayer, api: AudiobookshelfAPI, downloadManager: DownloadManager, onBookSelected: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: HomeViewModel(
            api: api,
            player: player,
            downloadManager: downloadManager,
            onBookSelected: onBookSelected
        ))
    }

    var body: some View {
        Group {
            switch viewModel.uiState {
            case .loading:
                LoadingView()
            case .error(let message):
                ErrorView(error: message)
            case .empty:
                EmptyStateView()
            case .noDownloads:
                NoDownloadsView()
            case .content:
                contentView
            }
        }
        .navigationTitle("Welcome back")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.loadPersonalizedBooks()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                settingsButton
            }
        }
        .alert("Error", isPresented: $viewModel.showingErrorAlert) {
            Button("OK") { }
            Button("Retry") {
                Task { await viewModel.loadPersonalizedBooks() }
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown Error")
        }
        .task {
            await viewModel.loadPersonalizedBooksIfNeeded()
        }
    }
    
    // MARK: - Subviews
    
    private var contentView: some View {
        ZStack {
            DynamicMusicBackground()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header mit Statistiken
                    homeHeaderView
                    
                    // Empfohlene Bücher
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("For your enjoyment")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Text("\(viewModel.personalizedBooks.count) Bücher")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        
                        // ✅ REUSE: HorizontalBookScrollView (gleich wie SeriesView!)
                        HorizontalBookScrollView(
                            books: viewModel.personalizedBooks,
                            player: viewModel.player,
                            api: viewModel.api,
                            downloadManager: viewModel.downloadManager,
                            cardStyle: .library,
                            onBookSelected: { book in
                                Task {
                                    await viewModel.loadAndPlayBook(book)
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 16)
            }
        }
    }
    
    private var homeHeaderView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Explore new books")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Quick Stats
            HStack(spacing: 20) {
                StatCard(
                    icon: "books.vertical.fill",
                    title: "Recommendations",
                    value: "\(viewModel.personalizedBooks.count)",
                    color: .blue
                )
                
                StatCard(
                    icon: "arrow.down.circle.fill",
                    title: "Downloaded",
                    value: "\(viewModel.downloadedCount)",
                    color: .green
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
    
    private var settingsButton: some View {
        Button(action: {
            NotificationCenter.default.post(name: .init("ShowSettings"), object: nil)
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
