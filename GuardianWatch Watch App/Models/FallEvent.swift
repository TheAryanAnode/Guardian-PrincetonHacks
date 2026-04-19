import Foundation

enum FallSeverity: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}

enum FallOutcome: String, Codable, CaseIterable {
    case cancelledByUser = "Cancelled by User"
    case helpRequested = "Help Requested"
    case noResponse = "No Response"
    case emergencyDispatched = "Emergency Dispatched"
    case falseAlarm = "False Alarm"
}

struct FallTrigger: Codable, Identifiable, Hashable {
    let id: UUID
    let description: String
    let value: String
    let icon: String

    init(description: String, value: String, icon: String) {
        self.id = UUID()
        self.description = description
        self.value = value
        self.icon = icon
    }
}

struct FallEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    var severity: FallSeverity
    var triggers: [FallTrigger]
    var outcome: FallOutcome?

    var peakGyro: Double
    var peakAcceleration: Double
    var stillnessDuration: Double

    var latitude: Double?
    var longitude: Double?

    var voiceResponseReceived: Bool
    var voiceResponse: String?

    var timelineEntries: [TimelineEntry]

    init(
        severity: FallSeverity = .medium,
        peakGyro: Double = 0,
        peakAcceleration: Double = 0,
        stillnessDuration: Double = 0
    ) {
        self.id = UUID()
        self.timestamp = .now
        self.severity = severity
        self.peakGyro = peakGyro
        self.peakAcceleration = peakAcceleration
        self.stillnessDuration = stillnessDuration
        self.triggers = []
        self.voiceResponseReceived = false
        self.timelineEntries = [
            TimelineEntry(event: "Fall detected", detail: "Sensor anomaly triggered")
        ]
    }
}

struct TimelineEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let event: String
    let detail: String

    init(event: String, detail: String) {
        self.id = UUID()
        self.timestamp = .now
        self.event = event
        self.detail = detail
    }
}
