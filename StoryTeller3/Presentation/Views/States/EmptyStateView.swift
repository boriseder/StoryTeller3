//
//  EmptyStateView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 23.09.25.
//

import SwiftUI

struct EmptyStateView: View {

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.yellow.gradient)
            
            VStack(spacing: 8) {
                Text("No data")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("There is nothing personalized for your account")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

