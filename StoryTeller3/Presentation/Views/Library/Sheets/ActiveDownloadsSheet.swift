//
//  ActiveDownloadsSheet.swift
//  StoryTeller3
//
//  Created by Boris Eder on 03.10.25.
//
import SwiftUI

struct ActiveDownloadsSheet: View {
    @ObservedObject var downloadManager: DownloadManager
    @Environment(\.dismiss) private var dismiss
    
    var activeDownloads: [Book] {
        downloadManager.downloadedBooks.filter { book in
            downloadManager.isDownloadingBook(book.id)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if activeDownloads.isEmpty {
                    ContentUnavailableView(
                        "No Active Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Downloads will appear here when in progress")
                    )
                } else {
                    ForEach(activeDownloads) { book in
                        DownloadProgressRow(
                            book: book,
                            downloadManager: downloadManager
                        )
                    }
                }
            }
            .navigationTitle("Active Downloads")
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

struct DownloadProgressRow: View {
    let book: Book
    @ObservedObject var downloadManager: DownloadManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Book info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let author = book.author {
                        Text(author)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Stage icon
                if let stage = downloadManager.downloadStage[book.id] {
                    Image(systemName: stage.icon)
                        .foregroundColor(.accentColor)
                }
            }
            
            // Progress bar
            if let progress = downloadManager.downloadProgress[book.id] {
                ProgressView(value: progress)
                    .tint(.accentColor)
                
                HStack {
                    // Status message
                    if let status = downloadManager.downloadStatus[book.id] {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Percentage
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
