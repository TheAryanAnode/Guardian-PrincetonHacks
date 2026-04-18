import SwiftUI

@Observable
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
    /// Live “AI” readout vs personalized baseline (updated while monitoring).
    var liveGaitInsight: GaitLiveInsight = .empty

    // MARK: - Navigation

    var selectedTab: AppTab = .dashboard
    var showOnboarding: Bool {
        !userProfile.hasCompletedOnboarding
    }

    // MARK: - API Configuration

    var openAIKey: String {
        get { UserDefaults.standard.string(forKey: "openai_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "openai_key") }
    }

    var elevenLabsKey: String {
        get { UserDefaults.standard.string(forKey: "elevenlabs_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "elevenlabs_key") }
    }

    /// Kimi K2 Thinking (OpenAI-compatible). Optional override URL if your key is routed through another gateway.
    var k2ThinkAPIKey: String {
        get { UserDefaults.standard.string(forKey: "k2_think_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "k2_think_key") }
    }

    var k2ThinkBaseURL: String {
        get { UserDefaults.standard.string(forKey: "k2_think_base_url") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "k2_think_base_url") }
    }

    var k2ThinkModel: String {
        get { UserDefaults.standard.string(forKey: "k2_think_model") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "k2_think_model") }
    }

    var resolvedK2ThinkModel: String {
        let stored = k2ThinkModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return stored.isEmpty ? Constants.API.k2ThinkDefaultModel : stored
    }

    // MARK: - Init

    init() {
        seedDemoAPIKeysIfNeeded()
        loadProfile()
        loadFallHistory()
        loadGaitHistory()
    }

    private func seedDemoAPIKeysIfNeeded() {
        // Only auto-fill if the user hasn't entered their own keys yet.
        if openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // keep OpenAI empty by default (K2 is preferred)
        }

        if elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            elevenLabsKey = Constants.API.defaultElevenLabsAPIKey
        }

        if k2ThinkAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            k2ThinkAPIKey = Constants.API.defaultK2ThinkAPIKey
        }

        if k2ThinkBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            k2ThinkBaseURL = Constants.API.k2ThinkDefaultBaseURL
        }

        if k2ThinkModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            k2ThinkModel = Constants.API.k2ThinkDefaultModel
        }
    }

    // MARK: - Fall Events

    func recordFallEvent(_ event: FallEvent) {
        fallHistory.insert(event, at: 0)
        saveFallHistory()
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
        LiveActivityManager.shared.updateActivity(
            status: isMonitoring ? .active : .inactive,
            gaitScore: Int(currentGaitScore),
            alertActive: false,
            countdown: nil
        )
    }

    // MARK: - Gait

    func recordGaitSample(_ record: GaitRecord) {
        gaitHistory.insert(record, at: 0)
        currentGaitScore = record.overallScore
        gaitRiskLevel = record.riskLevel

        if gaitHistory.count > 30 { gaitHistory = Array(gaitHistory.prefix(30)) }
        saveGaitHistory()

        if isMonitoring {
            LiveActivityManager.shared.updateActivity(
                status: .active,
                gaitScore: Int(record.overallScore),
                alertActive: false,
                countdown: nil
            )
        }
    }

    var gaitStatusText: String {
        switch gaitRiskLevel {
        case .low: return "Normal"
        case .moderate: return "Needs Attention"
        case .high: return "Consult Your Doctor"
        }
    }

    var weeklyFallCounts: [WeeklyFallCount] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<6).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: now),
                  let week = calendar.dateInterval(of: .weekOfYear, for: start) else {
                return nil
            }
            let count = fallHistory.filter { week.contains($0.timestamp) }.count
            let label = week.start.formatted(.dateTime.month(.abbreviated).day())
            return WeeklyFallCount(label: label, count: count, weekStart: week.start)
        }
    }

    func recalibrateGaitBaseline(duration: TimeInterval = 45) async {
        guard !isRecalibratingGait else { return }
        isRecalibratingGait = true
        defer { isRecalibratingGait = false }

        let wasMonitoring = isMonitoring
        if !wasMonitoring {
            MotionService.shared.startMonitoring(state: self)
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
            MotionService.shared.stopMonitoring()
        }
    }

    // MARK: - Persistence (UserDefaults for hackathon speed)

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

struct WeeklyFallCount: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let weekStart: Date
}

enum AppTab: String, CaseIterable {
    case dashboard = "Dashboard"
    case caregiver = "Caregiver"
    case settings  = "Settings"

    var icon: String {
        switch self {
        case .dashboard: return "heart.text.clipboard"
        case .caregiver: return "person.2"
        case .settings:  return "gearshape"
        }
    }
}
