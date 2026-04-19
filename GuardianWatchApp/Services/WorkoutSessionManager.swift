import Foundation
import HealthKit

/// Wraps an HKWorkoutSession so the watch keeps motion sampling active while
/// the wearer's wrist is down or the screen sleeps. Without this, watchOS
/// suspends the app within seconds of going to the background.
///
/// We use `.other` so this counts as a generic "safety monitoring" workout
/// rather than overstating it as a fitness session.
@MainActor
final class WorkoutSessionManager: NSObject {
    static let shared = WorkoutSessionManager()

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private(set) var isRunning = false

    private override init() { super.init() }

    /// Ask HealthKit for the bare-minimum types we need so the workout session can start.
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let toShare: Set = [HKObjectType.workoutType()]
        let toRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.activitySummaryType()
        ]
        return await withCheckedContinuation { cont in
            healthStore.requestAuthorization(toShare: toShare, read: toRead) { ok, _ in
                cont.resume(returning: ok)
            }
        }
    }

    /// Start a background-eligible monitoring session.
    func start() {
        guard !isRunning else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .unknown

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self

            self.session = session
            self.builder = builder

            let start = Date()
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    func stop() {
        guard isRunning else { return }
        session?.end()
        builder?.endCollection(withEnd: .now) { [weak self] _, _ in
            self?.builder?.finishWorkout { _, _ in }
        }
        session = nil
        builder = nil
        isRunning = false
    }
}

extension WorkoutSessionManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
}

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {}
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
