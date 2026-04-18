import ActivityKit
import Foundation

struct FallDetectionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: MonitoringStatus
        var gaitScore: Int
        var lastUpdate: Date
        var alertActive: Bool
        var countdown: Int?
    }

    var userName: String
}

enum MonitoringStatus: String, Codable, Hashable {
    case active = "MONITORING"
    case alert = "FALL DETECTED"
    case dispatching = "DISPATCHING"
    case inactive = "INACTIVE"
}
