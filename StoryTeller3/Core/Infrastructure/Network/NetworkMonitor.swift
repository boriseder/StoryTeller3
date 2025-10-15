import Foundation
import Network

enum NetworkStatus: Equatable, CustomStringConvertible {
    case online
    case offline
    case unknown
    
    var description: String {
        switch self {
        case .online: return "online"
        case .offline: return "offline"
        case .unknown: return "unknown"
        }
    }
}

protocol NetworkMonitoring {
    var isOnline: Bool { get }
    var currentStatus: NetworkStatus { get }
    func startMonitoring()
    func stopMonitoring()
}

class NetworkMonitor: NetworkMonitoring {
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.storyteller3.networkmonitor")
    private var statusHandler: ((NetworkStatus) -> Void)?
    
    private(set) var currentStatus: NetworkStatus = .unknown {
        didSet {
            if currentStatus != oldValue {
                statusHandler?(currentStatus)
                AppLogger.debug.debug("[NetworkMonitor] Status changed: \(self.currentStatus)")
            }
        }
    }
    
    var isOnline: Bool {
        currentStatus == .online
    }
    
    init() {}
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let newStatus: NetworkStatus = path.status == .satisfied ? .online : .offline
            
            Task { @MainActor in
                self?.currentStatus = newStatus
            }
        }
        
        monitor.start(queue: queue)
        AppLogger.debug.debug("[NetworkMonitor] Started monitoring")
    }
    
    func stopMonitoring() {
        monitor.cancel()
        AppLogger.debug.debug("[NetworkMonitor] Stopped monitoring")
    }
    
    func onStatusChange(_ handler: @escaping (NetworkStatus) -> Void) {
        self.statusHandler = handler
    }
    
    deinit {
        stopMonitoring()
    }
}
