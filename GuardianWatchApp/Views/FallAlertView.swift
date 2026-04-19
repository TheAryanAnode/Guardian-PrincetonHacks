import SwiftUI
import WatchKit

/// Full-screen modal shown the moment a fall is suspected. Two huge buttons
/// + a 30-second countdown. We use Watch haptics (`HapticsService`) and
/// optional spoken voice prompt — but unlike iOS we don't try to capture
/// audio for confirmation; tapping is more reliable on a wrist.
struct FallAlertView: View {
    @Bindable var state: AppState
    var fallEvent: FallEvent

    @State private var countdown = Constants.Alert.countdownDuration
    @State private var pulse = false
    @State private var timer: Timer?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                pulseHeader

                Text("FALL DETECTED")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Theme.accent)

                Text("Auto-call in \(countdown)s")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textMuted)

                Button {
                    cancel()
                } label: {
                    Label("I'm OK", systemImage: "hand.raised.fill")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 16, weight: .bold))
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(Theme.ledGreen)

                Button {
                    requestHelp()
                } label: {
                    Label("Get Help", systemImage: "phone.fill")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 16, weight: .bold))
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)

                if !fallEvent.triggers.isEmpty {
                    WatchCard {
                        Text("WHY")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.textMuted)
                        ForEach(fallEvent.triggers) { trigger in
                            HStack(spacing: 6) {
                                Image(systemName: trigger.icon)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 14)
                                Text(trigger.description)
                                    .font(.system(size: 11, weight: .medium))
                                Spacer()
                                Text(trigger.value)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
        }
        .containerBackground(Theme.background.gradient, for: .navigation)
        .onAppear { startCountdown() }
        .onDisappear { timer?.invalidate() }
    }

    private var pulseHeader: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.2))
                .frame(width: 70, height: 70)
                .scaleEffect(pulse ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)

            Image(systemName: "figure.fall")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.accent)
        }
        .onAppear { pulse = true }
    }

    private func startCountdown() {
        AIAgentService.shared.speakFallDetectionPrompt(
            userName: state.userProfile.name.isEmpty ? "" : state.userProfile.name
        )

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if countdown > 0 {
                    countdown -= 1
                    // Subtle tick every 5s, urgent failure haptic in last 5.
                    if countdown <= 5 { HapticsService.play(.failure) }
                    else if countdown.isMultiple(of: 5) { HapticsService.play(.click) }

                    // Repeat the spoken instruction so the wearer keeps hearing
                    // their options without needing to look at the screen.
                    if countdown > 5, countdown.isMultiple(of: 10) {
                        AIAgentService.shared.speakFallReminder()
                    } else if countdown == 5 {
                        AIAgentService.shared.speakImminentDispatch()
                    }
                } else {
                    timer?.invalidate()
                    state.dismissFallAlert(outcome: .noResponse)
                    await EmergencyDispatchService.shared.dispatchEmergency(
                        event: fallEvent, profile: state.userProfile
                    )
                }
            }
        }
    }

    private func cancel() {
        timer?.invalidate()
        AIAgentService.shared.stopSpeaking()
        HapticsService.cancelled()
        state.dismissFallAlert(outcome: .cancelledByUser)
    }

    private func requestHelp() {
        timer?.invalidate()
        AIAgentService.shared.stopSpeaking()
        HapticsService.dispatchTriggered()
        let event = fallEvent
        state.dismissFallAlert(outcome: .helpRequested)
        Task {
            await EmergencyDispatchService.shared.dispatchEmergency(
                event: event, profile: state.userProfile
            )
        }
    }
}
