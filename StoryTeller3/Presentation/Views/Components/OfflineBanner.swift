//
//  OfflineBanner.swift
//  StoryTeller3
//
//  Created by Boris Eder on 31.10.25.
//


import SwiftUI

struct OfflineBanner: View {
    let dataSource: DataSource
    let isOfflineMode: Bool
    
    var body: some View {
        if isOfflineMode, case .cache(let timestamp) = dataSource {
            HStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .font(.body)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Offline Mode")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Last updated \(formatTimestamp(timestamp))")
                        .font(.caption)
                        .opacity(0.8)
                }
                
                Spacer()
                
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .opacity(0.6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(0.9))
            .foregroundColor(.white)
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}