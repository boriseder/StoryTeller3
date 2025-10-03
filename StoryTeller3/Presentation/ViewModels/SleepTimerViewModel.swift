import SwiftUI
import UserNotifications

// MARK: - Sleep Timer Mode
enum SleepTimerMode: Equatable, CustomStringConvertible {
    case duration(minutes: Int)
    case endOfChapter
    case endOfBook
    
    var displayName: String {
        switch self {
        case .duration(let minutes):
            return "\(minutes) minutes"
        case .endOfChapter:
            return "End of chapter"
        case .endOfBook:
            return "End of book"
        }
    }
    
    // MARK: - CustomStringConvertible
    var description: String {
        switch self {
        case .duration(let minutes):
            return "duration(\(minutes)min)"
        case .endOfChapter:
            return "endOfChapter"
        case .endOfBook:
            return "endOfBook"
        }
    }
}

// MARK: - Timer State (for persistence)
private struct TimerState: Codable {
    let endDate: Date
    let mode: String
    
    enum CodingKeys: String, CodingKey {
        case endDate, mode
    }
}

// MARK: - Sleep Timer ViewModel
class SleepTimerViewModel: BaseViewModel {
    @Published var selectedMinutes: Int = 30
    @Published var isTimerActive = false
    @Published var remainingTime: TimeInterval = 0
    @Published var currentMode: SleepTimerMode?
    
    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.storyteller3.sleeptimer", qos: .utility)
    let player: AudioPlayer
    private let timerOptions = [5, 10, 15, 30, 45, 60, 90, 120]
    
    private var observers: [NSObjectProtocol] = []
    
    init(player: AudioPlayer) {
        self.player = player
        super.init()
        
        setupNotifications()
        restoreTimerState()
    }
    
    // MARK: - Public Interface
    
    var timerOptionsArray: [Int] {
        timerOptions
    }
    
    func startTimer(mode: SleepTimerMode) {
        cancelTimer()
        
        let duration: TimeInterval
        
        switch mode {
        case .duration(let minutes):
            duration = TimeInterval(minutes * 60)
            
        case .endOfChapter:
            guard let chapterEnd = player.currentChapter?.end else {
                AppLogger.debug.debug("[SleepTimer] Cannot start end-of-chapter timer - no chapter info")
                return
            }
            duration = max(0, chapterEnd - player.currentTime)
            
        case .endOfBook:
            duration = max(0, player.duration - player.currentTime)
        }
        
        guard duration > 0 else {
            AppLogger.debug.debug("[SleepTimer] Invalid timer duration: \(duration)")
            return
        }
        
        startTimerWithDuration(duration, mode: mode)
    }
    
    func cancelTimer() {
        timer?.cancel()
        timer = nil
        
        isTimerActive = false
        remainingTime = 0
        currentMode = nil
        
        clearTimerState()
        cancelTimerEndNotification()
        
        AppLogger.debug.debug("[SleepTimer] Timer cancelled")
    }
    
    // MARK: - Timer Implementation
    
    private func startTimerWithDuration(_ duration: TimeInterval, mode: SleepTimerMode) {
        let endDate = Date().addingTimeInterval(duration)
        
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: .seconds(1), leeway: .milliseconds(100))
        
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let remaining = endDate.timeIntervalSinceNow
            
            Task { @MainActor in
                self.remainingTime = max(0, remaining)
                
                if remaining <= 0 {
                    self.finishTimer()
                }
            }
        }
        
        self.timer = timer
        timer.resume()
        
        isTimerActive = true
        remainingTime = duration
        currentMode = mode
        
        saveTimerState(endDate: endDate, mode: mode)
        scheduleTimerEndNotification(fireDate: endDate)
        
        AppLogger.debug.debug("[SleepTimer] Timer started - duration: \(duration)s, mode: \(mode)")
    }
    
    private func finishTimer() {
        AppLogger.debug.debug("[SleepTimer] Timer finished - pausing playback")
        
        player.pause()
        
        cancelTimer()
        
        #if !targetEnvironment(simulator)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
        
        AppLogger.debug.debug("[SleepTimer] Sleep timer completed successfully")
    }
    
    // MARK: - Persistence
    
    private func saveTimerState(endDate: Date, mode: SleepTimerMode) {
        let modeString: String
        switch mode {
        case .duration(let minutes):
            modeString = "duration:\(minutes)"
        case .endOfChapter:
            modeString = "endOfChapter"
        case .endOfBook:
            modeString = "endOfBook"
        }
        
        let state = TimerState(endDate: endDate, mode: modeString)
        
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: "sleep_timer_state")
        }
    }
    
    private func restoreTimerState() {
        guard let data = UserDefaults.standard.data(forKey: "sleep_timer_state"),
              let state = try? JSONDecoder().decode(TimerState.self, from: data) else {
            return
        }
        
        let remaining = state.endDate.timeIntervalSinceNow
        
        guard remaining > 0 else {
            clearTimerState()
            return
        }
        
        let mode: SleepTimerMode
        if state.mode.starts(with: "duration:"),
           let minutes = Int(state.mode.replacingOccurrences(of: "duration:", with: "")) {
            mode = .duration(minutes: minutes)
        } else if state.mode == "endOfChapter" {
            mode = .endOfChapter
        } else if state.mode == "endOfBook" {
            mode = .endOfBook
        } else {
            clearTimerState()
            return
        }
        
        startTimerWithDuration(remaining, mode: mode)
        
        AppLogger.debug.debug("[SleepTimer] Restored timer state - remaining: \(remaining)s")
    }
    
    private func clearTimerState() {
        UserDefaults.standard.removeObject(forKey: "sleep_timer_state")
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if self?.isTimerActive == true {
                self?.saveCurrentTimerState()
            }
        }
        observers.append(backgroundObserver)
        
        requestNotificationPermission()
    }
    
    private func saveCurrentTimerState() {
        guard isTimerActive, let mode = currentMode else { return }
        let endDate = Date().addingTimeInterval(remainingTime)
        saveTimerState(endDate: endDate, mode: mode)
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                AppLogger.debug.debug("[SleepTimer] Notification permission error: \(error)")
            } else if granted {
                AppLogger.debug.debug("[SleepTimer] Notification permission granted")
            }
        }
    }
    
    private func scheduleTimerEndNotification(fireDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Sleep Timer"
        content.body = "Playback has been paused"
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            ),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "sleep_timer_end",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                AppLogger.debug.debug("[SleepTimer] Failed to schedule notification: \(error)")
            }
        }
    }
    
    private func cancelTimerEndNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["sleep_timer_end"]
        )
    }
    
    // MARK: - Cleanup
    
    deinit {
        timer?.cancel()
        observers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        AppLogger.debug.debug("[SleepTimer] ViewModel deinitialized")
    }
}
