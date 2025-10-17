//
//  EmptyStateView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 23.09.25.
//

import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        ZStack {
            Color.white.opacity(0.3)
                .frame(width: 360, height: 240)
                .cornerRadius(DSCorners.comfortable)
                .blur(radius: 0.5)

            VStack(spacing: DSLayout.contentGap) {
                Image(systemName: "rectangle.portrait.on.rectangle.portrait.slash")
                    .font(.system(size: 32))
                    .foregroundStyle(.black.gradient)
                    .frame(width: 40, height: 40)

                Text("No data")
                    .font(DSText.itemTitle)
            }
        }
        .padding(.horizontal, DSLayout.screenPadding)
    }
}


