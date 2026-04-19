import SwiftUI

@Observable
@MainActor
final class AppState {

    // MARK: - User

    var userProfile = UserProfile() {
        didSet { saveProfile() }
    }

    // MARK: - Monitoring

    var isMonitoring = false
    var currentSensorData: SensorSnapshot?
    var sensorHistory: [SensorSnapshot] = []

    // MARK: - Fall Detection

    var activeFallEvent: FallEvent?
    var fallHistory: [FallEvent] = []
    var showFallAlert = false

    // MARK: - Gait Analysis

    var currentGaitScore: Double = 0
    var gaitHistory: [GaitRecord] = []
    var gaitRiskLevel: GaitRiskLevel = .low
    var isRecalibratingGait = false
    var liveGaitInsight: GaitLiveInsight = .empty

    // MARK: - Navigation

    var selectedTab: WatchTab = .dashboard
    var showOnboarding: Bool { !userProfile.hasCompletedOnboarding }

    // MARK: - API Configuration (entered on iPhone via Watch Connectivity ideally,
    //         but kept here for parity with the iOS build).

    var openAIKey: String {
        get { UserDefaults.standard.string(forKey: "openai_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "openai_key") }
    }

    var elevenLabsKey: String {
        get { UserDefaults.standard.string(forKey: "elevenlabs_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "elevenlabs_key") }
    }

    // MARK: - Init

    init() {
        loadProfile()
        loadFallHistory()
        loadGaitHistory()
    }

    // MARK: - Fall Events

    func recordFallEvent(_ event: FallEvent) {
        fallHistory.insert(event, at: 0)
        saveFallHistory()
        WatchConnectivityService.shared.sendFallEvent(event, profile: userProfile)
    }

    func dismissFallAlert(outcome: FallOutcome) {
        if var event = activeFallEvent {
            event.outcome = outcome
            event.timelineEntries.append(
                TimelineEntry(event: "Resolved", detail: outcome.rawValue)
            )
            recordFallEvent(event)
        }
        activeFallEvent = nil
        showFallAlert = false
    }

    // MARK: - Gait

    func recordGaitSample(_ record: GaitRecord) {
        gaitHistory.insert(record, at: 0)
        currentGaitScore = record.overallScore
        gaitRiskLevel = record.riskLevel
        if gaitHistory.count > 30 { gaitHistory = Array(gaitHistory.prefix(30)) }
        saveGaitHistory()
    }

    var gaitStatusText: String {
        switch gaitRiskLevel {
        case .low:      return "Normal"
        case .moderate: return "Watch step"
        case .high:     return "See doctor"
        }
    }

    func recalibrateGaitBaseline(duration: TimeInterval = 45) async {
        guard !isRecalibratingGait else { return }
        isRecalibratingGait = true
        defer { isRecalibratingGait = false }

        let wasMonitoring = isMonitoring
        if !wasMonitoring {
            await MotionService.shared.startMonitoring(state: self)
        }
        GaitAnalysisService.shared.beginCalibrationWalk()
        try? await Task.sleep(for: .seconds(duration))
        if let result = GaitAnalysisService.shared.finalizeCalibrationWalk() {
            userProfile.gaitBaseline = result.baseline
            userProfile.baselineGaitScore = result.record.overallScore
            recordGaitSample(result.record)
            liveGaitInsight = GaitAnalysisService.shared.computeLiveInsight(baseline: result.baseline)
        } else {
            GaitAnalysisService.shared.cancelCalibrationWalk()
        }
        if !wasMonitoring {
            await MotionService.shared.stopMonitoring()
        }
    }

    // MARK: - Persistence

    private func saveProfile() {
        if let data = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(data, forKey: "user_profile")
        }
    }

    private func loadProfile() {
        if let data = UserDefaults.standard.data(forKey: "user_profile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            userProfile = profile
        }
    }

    private func saveFallHistory() {
        if let data = try? JSONEncoder().encode(Array(fallHistory.prefix(50))) {
            UserDefaults.standard.set(data, forKey: "fall_history")
        }
    }

    private func loadFallHistory() {
        if let data = UserDefaults.standard.data(forKey: "fall_history"),
           let history = try? JSONDecoder().decode([FallEvent].self, from: data) {
            fallHistory = history
        }
    }

    private func saveGaitHistory() {
        if let data = try? JSONEncoder().encode(Array(gaitHistory.prefix(30))) {
            UserDefaults.standard.set(data, forKey: "gait_history")
        }
    }

    private func loadGaitHistory() {
        if let data = UserDefaults.standard.data(forKey: "gait_history"),
           let history = try? JSONDecoder().decode([GaitRecord].self, from: data) {
            gaitHistory = history
            if let latest = history.first {
                currentGaitScore = latest.overallScore
                gaitRiskLevel = latest.riskLevel
            }
        }
    }
}

enum WatchTab: String, CaseIterable, Hashable {
    case dashboard = "Status"
    case history   = "Falls"
    case gait      = "Gait"
    case settings  = "Settings"

    var icon: String {
        switch self {
        case .dashboard: return "shield.checkered"
        case .history:   return "list.bullet.clipboard"
        case .gait:      return "figure.walk.motion"
        case .settings:  return "gearshape"
        }
    }
}
