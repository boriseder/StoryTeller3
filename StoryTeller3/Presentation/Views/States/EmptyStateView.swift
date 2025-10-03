//
//  EmptyStateView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 23.09.25.
//

import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        StateContainer {
            VStack(spacing: 32) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.yellow.gradient)
                    .frame(width: 80, height: 80) // Consistent sizing
                
                VStack(spacing: 8) {
                    Text("No data")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("There is nothing personalized for your account")
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
