//
//  SleepTimerView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 09.09.25.
//


//
//  SleepTimerView.swift
//  StoryTeller3
//
//  Created by Boris Eder on 09.09.25.
//

import SwiftUI

struct SleepTimerView: View {
    @StateObject private var viewModel: SleepTimerViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(player: AudioPlayer) {
        self._viewModel = StateObject(wrappedValue: SleepTimerViewModel(player: player))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if viewModel.isTimerActive {
                    activeSleepTimerView
                } else {
                    sleepTimerOptionsView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var activeSleepTimerView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Sleep Timer Active")
                    .font(.headline)
                
                Text(TimeFormatter.formatTime(viewModel.remainingTime))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            
            Button("Cancel Timer") {
                viewModel.cancelTimer()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
    
    private var sleepTimerOptionsView: some View {
        VStack(spacing: 16) {
            Text("Set Sleep Timer")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(viewModel.timerOptionsArray, id: \.self) { minutes in
                    Button(action: {
                        viewModel.startTimer(minutes: minutes)
                    }) {
                        VStack(spacing: 4) {
                            Text("\(minutes)")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text(minutes == 1 ? "minute" : "minutes")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
}