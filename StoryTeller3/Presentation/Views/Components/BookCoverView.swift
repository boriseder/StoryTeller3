//
//  BookCoverView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 03.10.25.
//
import SwiftUI

// MARK: - Book Cover View
struct BookCoverView: View {
    let book: Book
    let api: AudiobookshelfAPI?
    let downloadManager: DownloadManager?
    let size: CGSize
    let showLoadingProgress: Bool
    
    @StateObject private var loader: BookCoverLoader
    
    init(
        book: Book,
        api: AudiobookshelfAPI? = nil,
        downloadManager: DownloadManager? = nil,
        size: CGSize,
        showLoadingProgress: Bool = false
    ) {
        self.book = book
        self.api = api
        self.downloadManager = downloadManager
        self.size = size
        self.showLoadingProgress = showLoadingProgress
        self._loader = StateObject(wrappedValue: BookCoverLoader(
            book: book,
            api: api,
            downloadManager: downloadManager
        ))
    }
    
    var body: some View {
        ZStack {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if loader.isLoading {
                loadingView
            } else {
                placeholderView
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            loader.load()
        }
        .onChange(of: book.id) {
            loader.load()
        }
        .onDisappear {
            loader.cancelLoading()
        }
        .animation(.easeInOut(duration: 0.3), value: loader.image != nil)
    }
    
    private var loadingView: some View {
        ZStack {
            Color.gray.opacity(0.2)
            
            VStack(spacing: 8) {
                if showLoadingProgress && loader.downloadProgress > 0 {
                    ProgressView(value: loader.downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                        .frame(width: size.width * 0.6)
                    
                    Text("\(Int(loader.downloadProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.accentColor)
                }
            }
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.3),
                    Color.accentColor.opacity(0.6),
                    Color.accentColor.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: max(size.width * 0.08, 8)) {
                Image(systemName: loader.hasError ? "exclamationmark.triangle.fill" : "book.closed.fill")
                    .font(.system(size: size.width * 0.25))
                    .foregroundColor(.white)
                
                if size.width > 100 {
                    Text(loader.hasError ? "Cover nicht verfügbar" : book.title)
                        .font(.system(size: size.width * 0.08, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 8)
                }
            }
        }
    }
}

// MARK: - Convenience Extensions
extension BookCoverView {
    /// Creates a square cover view
    static func square(
        book: Book,
        size: CGFloat,
        api: AudiobookshelfAPI? = nil,
        downloadManager: DownloadManager? = nil,
        showProgress: Bool = false
    ) -> BookCoverView {
        BookCoverView(
            book: book,
            api: api,
            downloadManager: downloadManager,
            size: CGSize(width: size, height: size),
            showLoadingProgress: showProgress
        )
    }
    
    /// Creates a cover view with typical book aspect ratio (3:4)
    static func bookAspect(
        book: Book,
        width: CGFloat,
        api: AudiobookshelfAPI? = nil,
        downloadManager: DownloadManager? = nil,
        showProgress: Bool = false
    ) -> BookCoverView {
        let height = width * 4/3
        return BookCoverView(
            book: book,
            api: api,
            downloadManager: downloadManager,
            size: CGSize(width: width, height: height),
            showLoadingProgress: showProgress
        )
    }
}
