//
//  NoDownloadsView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 23.09.25.
//

import SwiftUI

struct NoDownloadsView: View {
    var body: some View {
        StateContainer {
            VStack(spacing: 32) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 80))
                    .foregroundStyle(.orange.gradient)
                    .frame(width: 80, height: 80)
                
                VStack(spacing: 8) {
                    Text("No downloaded books found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("You haven't downloaded any books. Download books to enjoy them offline.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 40)
        }
    }
}
