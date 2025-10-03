//
//  ErrorView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 23.09.25.
//

import SwiftUI

struct ErrorView: View {
    let error: String
    
    var body: some View {
        StateContainer {
            VStack(spacing: 24) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 60))
                    .foregroundStyle(.red.gradient)
                    .frame(width: 80, height: 80) // Consistent sizing
                
                VStack(spacing: 12) {
                    Text("Connection error")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true) // Prevent layout shifts
                }
                .padding(.horizontal, 40)
            }
            .padding(40)
        }
    }
}
