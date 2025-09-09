//
//  BaseViewModel.swift
//  StoryTeller3
//
//  Created by Boris Eder on 09.09.25.
//

import SwiftUI

// MARK: - Base ViewModel
class BaseViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingErrorAlert = false
    
    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        isLoading = false
        showingErrorAlert = true
    }
    
    func resetError() {
        errorMessage = nil
        showingErrorAlert = false
    }
}
