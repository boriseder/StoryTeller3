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
            .onDisappear {
                // Timer continues running even when view is dismissed
                AppLogger.debug.debug("[SleepTimerView] View dismissed, timer state: \(viewModel.isTimerActive)")
            }
        }
    }
    
    private var activeSleepTimerView: some View {
        VStack(spacing: 24) {
            // Timer Status Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "moon.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                Text("Sleep Timer Active")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(TimeFormatter.formatTime(viewModel.remainingTime))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                Text("Playback will pause automatically")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("You can close this screen safely")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Cancel Timer") {
                AppLogger.debug.debug("[SleepTimerView] Cancel timer button tapped")
                viewModel.cancelTimer()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
    
    private var sleepTimerOptionsView: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "moon.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Set Sleep Timer")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Playback will pause automatically after the selected time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Timer Options Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(viewModel.timerOptionsArray, id: \.self) { minutes in
                    Button(action: {
                        AppLogger.debug.debug("[SleepTimerView] Timer option selected: \(minutes) minutes")
                        viewModel.startTimer(minutes: minutes)
                    }) {
                        VStack(spacing: 8) {
                            Text("\(minutes)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text(minutes == 1 ? "minute" : "minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Info text
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("The timer will continue running in the background")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("You can continue using other parts of the app")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }
}
