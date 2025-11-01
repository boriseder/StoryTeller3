//
//  DebugView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 17.10.25.
//


import SwiftUI

enum DebugSheet: Identifiable {
    case authError, emptyState, error, loading, networkError, noDownloads, noSearchResults

    var id: Int { hashValue }
}

struct DebugView: View {
    @State private var selectedSheet: DebugSheet?
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    debugButton("AuthErrorView") { selectedSheet = .authError }
                    debugButton("EmptyStateView") { selectedSheet = .emptyState }
                    debugButton("ErrorView") { selectedSheet = .error }
                    debugButton("LoadingView") { selectedSheet = .loading }
                    debugButton("NetworkErrorView") { selectedSheet = .networkError }
                    debugButton("NoDownloadsView") { selectedSheet = .noDownloads }
                    debugButton("NoSearchResultsView") { selectedSheet = .noSearchResults }
                }
                .padding()
            }
            .navigationTitle("Debug View")
        }
        .sheet(item: $selectedSheet) { sheet in
            ZStack {
                if theme.backgroundStyle == .dynamic {
                    DynamicBackground()
                }
                switch sheet {
                case .authError:
                    AuthErrorView(onReLogin: {})
                case .emptyState:
                    EmptyStateView()
                case .error:
                    ErrorView(error: "Fehler beim Laden")
                case .loading:
                    LoadingView()
                case .networkError:
                    NetworkErrorView(
                        issueType: .serverUnreachable,
                        downloadedBooksCount: 3,
                        onRetry: {},
                        onViewDownloads: {},
                        onSettings: {}
                    )
                case .noDownloads:
                    NoDownloadsView()
                case .noSearchResults:
                    NoSearchResultsView()
                }
            }
        }
    }

    private func debugButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
    }
}
