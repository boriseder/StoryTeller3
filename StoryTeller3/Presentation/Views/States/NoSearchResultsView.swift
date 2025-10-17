//
//  NoSearchResultsView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 23.09.25.
//

import SwiftUI

struct NoSearchResultsView: View {

    var body: some View {
        ZStack {
            Color.white.opacity(0.3)
                .frame(width: 360, height: 240)
                .cornerRadius(DSCorners.comfortable)
                .blur(radius: 0.5)

            VStack(spacing: DSLayout.contentGap) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(.black.gradient)
                    .frame(width: 40, height: 40)

                VStack(spacing: 8) {
                    Text("No results")
                        .font(DSText.itemTitle)

                    Text("Try another search query.")
                        .font(DSText.footnote)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

