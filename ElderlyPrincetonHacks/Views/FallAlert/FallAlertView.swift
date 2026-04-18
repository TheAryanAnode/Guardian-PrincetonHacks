import SwiftUI

struct FallAlertView: View {
    @Bindable var state: AppState
    var fallEvent: FallEvent

    @State private var countdown = Constants.Alert.countdownDuration
    @State private var showVoiceCheck = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Theme.chassis.ignoresSafeArea()

            VStack(spacing: 0) {
                alertHeader
                    .padding(.top, 60)
                    .padding(.bottom, 24)

                ScrollView {
                    VStack(spacing: 20) {
                        countdownSection
                        FallReasonView(triggers: fallEvent.triggers)
                            .padding(.horizontal, 20)

                        if showVoiceCheck {
                            FallConfirmationView(state: state)
                                .padding(.horizontal, 20)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                }

                actionButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
        .onAppear { startCountdown() }
        .onDisappear {
            timer?.invalidate()
            AudioClassificationService.shared.stopListening()
        }
    }

    private var alertHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: pulseScale
                    )

                Circle()
                    .fill(Theme.accent.opacity(0.3))
                    .frame(width: 70, height: 70)

                Image(systemName: "figure.fall")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .onAppear { pulseScale = 1.3 }

            Text("FALL DETECTED")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundColor(Theme.accent)

            Text("Severity: \(fallEvent.severity.rawValue)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(Theme.textMuted)
        }
    }

    private var countdownSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Theme.recessed, lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(countdown) / CGFloat(Constants.Alert.countdownDuration))
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: countdown)

                VStack(spacing: 2) {
                    Text("\(countdown)")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.accent)
                    Text("SEC")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(Theme.textMuted)
                }
            }

            Text("Emergency dispatch in \(countdown) seconds")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.textMuted)
        }
        .padding(.horizontal, 20)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            NeuButton(
                title: "I'm OK -- Cancel",
                icon: "hand.raised",
                variant: .secondary,
                isFullWidth: true
            ) {
                timer?.invalidate()
                state.dismissFallAlert(outcome: .cancelledByUser)
            }

            NeuButton(
                title: "Get Help Now",
                icon: "phone.fill",
                variant: .primary,
                isFullWidth: true
            ) {
                timer?.invalidate()
                state.dismissFallAlert(outcome: .helpRequested)
                Task {
                    await EmergencyDispatchService.shared.dispatchEmergency(
                        event: fallEvent,
                        profile: state.userProfile
                    )
                }
            }
        }
    }

    private func startCountdown() {
        showVoiceCheck = true

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if countdown > 0 {
                    countdown -= 1
                    LiveActivityManager.shared.updateActivity(
                        status: .alert,
                        gaitScore: Int(state.currentGaitScore),
                        alertActive: true,
                        countdown: countdown
                    )
                } else {
                    timer?.invalidate()
                    state.dismissFallAlert(outcome: .noResponse)
                    await EmergencyDispatchService.shared.dispatchEmergency(
                        event: fallEvent,
                        profile: state.userProfile
                    )
                }
            }
        }

        LiveActivityManager.shared.updateActivity(
            status: .alert,
            gaitScore: Int(state.currentGaitScore),
            alertActive: true,
            countdown: countdown
        )
    }
}
