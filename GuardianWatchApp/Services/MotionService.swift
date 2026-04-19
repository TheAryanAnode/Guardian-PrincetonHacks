import Foundation
import CoreMotion

/// CoreMotion still works on watchOS — but we pair it with an HKWorkoutSession
/// (see WorkoutSessionManager) so the OS doesn't suspend the app while the
/// wrist is down. Sample rate is 50 Hz on the wrist for battery.
@MainActor
final class MotionService {
    static let shared = MotionService()

    private let motionManager = CMMotionManager()
    private weak var state: AppState?
    private var fallDetectionEngine: FallDetectionEngine?
    private var gaitInsightTick = 0

    private init() {}

    var isAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }

    func startMonitoring(state: AppState) async {
        self.state = state
        self.fallDetectionEngine = FallDetectionEngine(state: state)

        guard isAvailable else { return }

        // Background-eligible workout session keeps us alive on the wrist.
        WorkoutSessionManager.shared.start()

        motionManager.deviceMotionUpdateInterval = Constants.Motion.updateInterval

        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: .main
        ) { [weak self] motion, error in
            guard let self, let motion, error == nil else { return }

            let snapshot = SensorSnapshot(
                rotationX: motion.rotationRate.x,
                rotationY: motion.rotationRate.y,
                rotationZ: motion.rotationRate.z,
                accelerationX: motion.userAcceleration.x,
                accelerationY: motion.userAcceleration.y,
                accelerationZ: motion.userAcceleration.z,
                gravityX: motion.gravity.x,
                gravityY: motion.gravity.y,
                gravityZ: motion.gravity.z,
                pitchRadians: motion.attitude.pitch
            )

            Task { @MainActor in
                self.state?.currentSensorData = snapshot
                self.state?.sensorHistory.append(snapshot)
                GaitAnalysisService.shared.addSample(snapshot)

                if (self.state?.sensorHistory.count ?? 0) > 600 {
                    self.state?.sensorHistory.removeFirst(300)
                }

                // Refresh live insight every ~1s (50 Hz × 50 samples).
                self.gaitInsightTick += 1
                if self.gaitInsightTick % 50 == 0,
                   let appState = self.state,
                   appState.isMonitoring,
                   appState.userProfile.gaitBaseline != nil {
                    let insight = GaitAnalysisService.shared.computeLiveInsight(
                        baseline: appState.userProfile.gaitBaseline
                    )
                    appState.liveGaitInsight = insight
                    appState.currentGaitScore = insight.gaitScore
                    appState.gaitRiskLevel = insight.gaitRiskLevel
                }

                self.fallDetectionEngine?.processSensorData(snapshot)
            }
        }

        state.isMonitoring = true
    }

    func stopMonitoring() async {
        motionManager.stopDeviceMotionUpdates()
        state?.isMonitoring = false
        WorkoutSessionManager.shared.stop()
        fallDetectionEngine = nil
    }
}
