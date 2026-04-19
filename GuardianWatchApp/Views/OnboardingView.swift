import SwiftUI
import UserNotifications

/// Compressed 3-step onboarding tuned for the watch screen. Each step is a
/// single page; user navigates with the Digital Crown / vertical TabView.
struct OnboardingView: View {
    @Bindable var state: AppState

    @State private var step = 0
    @State private var name = ""
    @State private var permissionsGranted = false
    @State private var calibrating = false
    @State private var progress: Double = 0

    var body: some View {
        TabView(selection: $step) {
            welcomeStep.tag(0)
            permissionsStep.tag(1)
            profileStep.tag(2)
            calibrationStep.tag(3)
        }
        .tabViewStyle(.verticalPage)
        .containerBackground(Theme.background.gradient, for: .tabView)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text("Guardian")
                .font(.system(size: 22, weight: .bold))
            Text("Wrist-based fall detection & gait monitoring.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textMuted)
            Button("Continue") { step = 1 }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
        .padding()
    }

    private var permissionsStep: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text("Permissions")
                .font(.headline)
            Text("Motion, HealthKit (workout), Location, Notifications.")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textMuted)

            Button {
                Task {
                    await requestPermissions()
                    if permissionsGranted { step = 2 }
                }
            } label: {
                Text(permissionsGranted ? "Granted ✓" : "Grant")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(permissionsGranted ? Theme.ledGreen : Theme.accent)

            if Constants.Demo.isEnabled {
                Button("Skip (demo)") { step = 2 }
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .padding()
    }

    private var profileStep: some View {
        VStack(spacing: 10) {
            Text("Your name")
                .font(.headline)
            TextField("Name", text: $name)
                .textFieldStyle(.plain)

            Button("Next") {
                state.userProfile.name = name
                step = 3
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(name.isEmpty)
        }
        .padding()
    }

    private var calibrationStep: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Theme.surfaceHi, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if calibrating {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                } else if progress >= 1.0 {
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.ledGreen)
                } else {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .frame(width: 90, height: 90)

            Text(calibrating ? "Walk for \(Int(Constants.GaitAnalysis.baselineCalibrationDuration))s"
                            : (progress >= 1 ? "Done" : "Calibrate"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textMuted)

            if !calibrating && progress < 1.0 {
                Button("Start") { startCalibration() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            } else if progress >= 1.0 {
                Button("Finish") { complete() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.ledGreen)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func requestPermissions() async {
        LocationService.shared.requestPermission()
        let hk = await WorkoutSessionManager.shared.requestAuthorization()
        let center = UNUserNotificationCenter.current()
        let notif = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        permissionsGranted = hk && notif
    }

    private func startCalibration() {
        calibrating = true
        progress = 0
        Task { await MotionService.shared.startMonitoring(state: state) }
        GaitAnalysisService.shared.beginCalibrationWalk()

        let duration = Constants.GaitAnalysis.baselineCalibrationDuration
        let tickInterval: TimeInterval = 0.1
        let increment = tickInterval / duration

        Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { timer in
            Task { @MainActor in
                progress += increment
                if progress >= 1.0 {
                    progress = 1.0
                    timer.invalidate()
                    calibrating = false
                    await MotionService.shared.stopMonitoring()
                    if let result = GaitAnalysisService.shared.finalizeCalibrationWalk() {
                        state.userProfile.gaitBaseline = result.baseline
                        state.userProfile.baselineGaitScore = result.record.overallScore
                        state.recordGaitSample(result.record)
                    } else {
                        // In demo mode we may not have walked at all — fabricate
                        // a baseline so the user can finish onboarding.
                        if Constants.Demo.isEnabled {
                            state.userProfile.gaitBaseline = GaitBaseline(
                                avgCadence: 105,
                                avgAccelVariance: 0.18,
                                avgForwardTiltDegrees: 8,
                                sampleCount: 0,
                                recordedAt: .now,
                                compositeGaitScore: 78
                            )
                            state.userProfile.baselineGaitScore = 78
                            state.recordGaitSample(
                                GaitRecord(cadence: 105, strideRegularity: 78,
                                           symmetry: 80, smoothness: 76)
                            )
                        } else {
                            GaitAnalysisService.shared.cancelCalibrationWalk()
                        }
                    }
                }
            }
        }
    }

    private func complete() {
        state.userProfile.hasCompletedOnboarding = true
    }
}
