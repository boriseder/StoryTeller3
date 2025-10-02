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
        VStack(spacing: 32) {
            Image(systemName: "key.slash.fill")
                .font(.system(size: 80))
                .foregroundStyle(.yellow.gradient)
            
            VStack(spacing: 12) {
                Text("Authentication Failed")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Your credentials are invalid or have expired. Please log in again.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onReLogin) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Update Credentials")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}