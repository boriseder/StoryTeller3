import SwiftUI

struct SleepTimerView: View {
    @EnvironmentObject private var sleepTimer: SleepTimerService  // ADD THIS
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if sleepTimer.isTimerActive {
                        activeSleepTimerView
                    } else {
                        sleepTimerOptionsView
                    }
                }
                .padding()
            }
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
                AppLogger.general.debug("[SleepTimerView] View dismissed, timer state: \(sleepTimer.isTimerActive)")
            }
        }
    }
    
    // MARK: - Active Timer View
    
    private var activeSleepTimerView: some View {
        VStack(spacing: 32) {
            timerStatusIcon
            
            timerCountdown
            
            timerModeInfo
            
            timerInstructions
            
            cancelButton
            
            Spacer()
        }
    }
    
    private var timerStatusIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.2),
                            Color.blue.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)
            
            Circle()
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                .frame(width: 140, height: 140)
            
            Image(systemName: "moon.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .symbolEffect(.pulse, value: sleepTimer.isTimerActive)
        }
    }
    
    private var timerCountdown: some View {
        VStack(spacing: 12) {
            Text("Sleep Timer Active")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(TimeFormatter.formatTime(sleepTimer.remainingTime))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.blue)
                .contentTransition(.numericText())
                .animation(.smooth, value: sleepTimer.remainingTime)
            
            Text("remaining")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var timerModeInfo: some View {
        Group {
            if let mode = sleepTimer.currentMode {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: modeIcon(for: mode))
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text(mode.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
    }
    
    private var timerInstructions: some View {
        VStack(spacing: 12) {
            instructionRow(
                icon: "pause.circle.fill",
                text: "Playback will pause automatically"
            )
            
            instructionRow(
                icon: "apps.iphone",
                text: "You can close this screen safely"
            )
            
            instructionRow(
                icon: "bell.fill",
                text: "You'll receive a notification when the timer ends"
            )
        }
        .padding(.horizontal, 8)
    }
    
    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: DSLayout.contentGap) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
    
    private var cancelButton: some View {
        Button(action: {
            AppLogger.general.debug("[SleepTimerView] Cancel timer button tapped")
            sleepTimer.cancelTimer()
        }) {
            HStack {
                Image(systemName: "xmark.circle.fill")
                Text("Cancel Timer")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Timer Options View
    
    private var sleepTimerOptionsView: some View {
        VStack(spacing: 32) {
            headerSection
            
            durationOptionsSection
            
            smartOptionsSection
            
            infoSection
            
            Spacer()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.2),
                                Color.blue.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "moon.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                Text("Set Sleep Timer")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Playback will pause automatically")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var durationOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Time Duration")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(sleepTimer.timerOptionsArray, id: \.self) { minutes in
                    durationOptionButton(minutes: minutes)
                }
            }
        }
    }
    
    private func durationOptionButton(minutes: Int) -> some View {
        Button(action: {
            AppLogger.general.debug("[SleepTimerView] Timer option selected: \(minutes) minutes")
            sleepTimer.startTimer(mode: .duration(minutes: minutes))
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
                    .fill(Color.blue.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var smartOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Smart Options")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 12) {
                if sleepTimer.player.currentChapter != nil {
                    smartOptionButton(
                        icon: "book.pages.fill",
                        title: "End of Current Chapter",
                        subtitle: "Pause when chapter finishes",
                        action: {
                            AppLogger.general.debug("[SleepTimerView] End of chapter option selected")
                            sleepTimer.startTimer(mode: .endOfChapter)
                        }
                    )
                }
                
                smartOptionButton(
                    icon: "book.closed.fill",
                    title: "End of Book",
                    subtitle: "Pause when book finishes",
                    action: {
                        AppLogger.general.debug("[SleepTimerView] End of book option selected")
                        sleepTimer.startTimer(mode: .endOfBook)
                    }
                )
            }
        }
    }
    
    private func smartOptionButton(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var infoSection: some View {
        VStack(spacing: 12) {
            infoRow(
                icon: "arrow.clockwise.circle.fill",
                text: "Timer continues running in the background",
                color: .blue
            )
            
            infoRow(
                icon: "bell.badge.fill",
                text: "Receive a notification when timer ends",
                color: .orange
            )
            
            infoRow(
                icon: "apps.iphone",
                text: "Continue using other parts of the app",
                color: .green
            )
        }
        .padding(.top, 8)
    }
    
    private func infoRow(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Helper Methods
    
    private func modeIcon(for mode: SleepTimerMode) -> String {
        switch mode {
        case .duration:
            return "clock.fill"
        case .endOfChapter:
            return "book.pages.fill"
        case .endOfBook:
            return "book.closed.fill"
        }
    }
}

