//
//  NetworkErrorView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 02.10.25.
//


import SwiftUI

struct NetworkErrorView: View {
    let issueType: ConnectionIssueType
    let downloadedBooksCount: Int
    let onRetry: () -> Void
    let onViewDownloads: () -> Void
    let onSettings: () -> Void
    
    var body: some View {
        StateContainer {
            VStack(spacing: 32) {
                Image(systemName: issueType.systemImage)
                    .font(.system(size: 80))
                    .foregroundStyle(issueType.iconColor.gradient)
                    .frame(width: 80, height: 80) // Consistent sizing
                
                VStack(spacing: 12) {
                    Text(issueType.userMessage)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(issueType.detailMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if downloadedBooksCount > 0 {
                    VStack(spacing: 12) {
                        Divider()
                            .padding(.vertical, 8)
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("You have \(downloadedBooksCount) book\(downloadedBooksCount == 1 ? "" : "s") downloaded")
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: onViewDownloads) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("View Downloaded Books")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .clipShape(Capsule())
                        }
                    }
                }
                
                VStack(spacing: 12) {
                    if issueType.canRetry {
                        Button(action: onRetry) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry Connection")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                        }
                    }
                    
                    Button(action: onSettings) {
                        Text("Check Settings")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
