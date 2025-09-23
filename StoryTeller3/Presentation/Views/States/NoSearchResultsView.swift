//
//  NoSearchResultsView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 23.09.25.
//

import SwiftUI

struct NoSearchResultsView: View {

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 80))
                .foregroundStyle(.gray.gradient)
            
            VStack(spacing: 8) {
                Text("No results")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Try another search query.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

