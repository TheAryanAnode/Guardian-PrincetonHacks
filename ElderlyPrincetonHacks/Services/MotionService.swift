import Foundation
import CoreMotion

@MainActor
final class MotionService {
    static let shared = MotionService()

    private let motionManager = CMMotionManager()
    private var state: AppState?
    private var fallDetectionEngine: FallDetectionEngine?
    private var gaitInsightTick = 0

    private init() {}

    var isAvailable: Bool {
        motionManager.isGyroAvailable && motionManager.isAccelerometerAvailable
    }

    func startMonitoring(state: AppState) {
        self.state = state
        self.fallDetectionEngine = FallDetectionEngine(state: state)

        guard isAvailable else { return }

        motionManager.gyroUpdateInterval = Constants.Motion.updateInterval
        motionManager.accelerometerUpdateInterval = Constants.Motion.updateInterval

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

                if (self.state?.sensorHistory.count ?? 0) > 1000 {
                    self.state?.sensorHistory.removeFirst(500)
                }

                self.gaitInsightTick += 1
                if self.gaitInsightTick % 45 == 0,
                   let state = self.state,
                   state.isMonitoring,
                   state.userProfile.gaitBaseline != nil {
                    let insight = GaitAnalysisService.shared.computeLiveInsight(
                        baseline: state.userProfile.gaitBaseline
                    )
                    state.liveGaitInsight = insight
                    state.currentGaitScore = insight.gaitScore
                    state.gaitRiskLevel = insight.gaitRiskLevel
                }

                self.fallDetectionEngine?.processSensorData(snapshot)
            }
        }

        state.isMonitoring = true
        let name = state.userProfile.name.isEmpty ? "User" : state.userProfile.name
        LiveActivityManager.shared.startMonitoringActivity(
            userName: name,
            gaitScore: Int(state.currentGaitScore)
        )
    }

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        state?.isMonitoring = false
        LiveActivityManager.shared.endActivity()
        fallDetectionEngine = nil
    }
}
