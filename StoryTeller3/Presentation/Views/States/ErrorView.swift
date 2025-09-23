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
        VStack(spacing: 24) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 60))
                .foregroundStyle(.red.gradient)
            
            VStack(spacing: 12) {
                Text("Connection error")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
