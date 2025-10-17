//
//  AuthErrorView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 02.10.25.
//


import SwiftUI

struct AuthErrorView: View {
    let onReLogin: () -> Void
    
    var body: some View {
        ZStack {
            Color.white.opacity(0.3)
                .frame(width: 360, height: 240)
                .cornerRadius(DSCorners.comfortable)
                .blur(radius: 0.5)

            VStack(spacing: DSLayout.contentGap) {
                Image(systemName: "key.slash.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.black.gradient)
                    .frame(width: 40, height: 40)
                
                VStack(spacing: 12) {
                    Text("Authentication Failed")
                        .font(DSText.itemTitle)
                    
                    Text("Your credentials are invalid or have expired. Please log in again.")
                        .font(DSText.footnote)
                        .multilineTextAlignment(.center)
                }
                    
                Button(action: onReLogin) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Update Credentials")
                    }
                    .font(DSText.detail)
                    .foregroundColor(.white)
                    .padding(.horizontal, DSLayout.elementPadding)
                    .padding(.vertical, DSLayout.elementPadding)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, DSLayout.screenPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
