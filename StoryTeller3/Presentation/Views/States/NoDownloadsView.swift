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
                    Text("Keine Downloads gefunden")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Du hast noch keine Bücher heruntergeladen. Lade Bücher herunter, um sie offline zu hören.")
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
