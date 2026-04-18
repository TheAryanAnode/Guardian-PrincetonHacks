import SwiftUI

struct FallConfirmationView: View {
    @Bindable var state: AppState
    @StateObject private var audioService = AudioClassificationService.shared
    @StateObject private var aiAgent = AIAgentService.shared

    @State private var isListeningForResponse = false
    @State private var responseText = ""
    @State private var showWaveform = false
    @State private var hasRunVoiceCheck = false

    var body: some View {
        VStack(spacing: 20) {
            waveformIndicator

            VStack(spacing: 8) {
                Text(aiAgent.isSpeaking ? "SPEAKING..." : (isListeningForResponse ? "LISTENING..." : "PROCESSING..."))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Theme.accent)

                if !responseText.isEmpty {
                    Text("\"\(responseText)\"")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
        }
        .task {
            guard !hasRunVoiceCheck else { return }
            hasRunVoiceCheck = true
            await runVoiceCheck()
        }
    }

    private var waveformIndicator: some View {
        HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent)
                    .frame(width: 4, height: showWaveform ? CGFloat.random(in: 12...36) : 8)
                    .animation(
                        .easeInOut(duration: 0.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.1),
                        value: showWaveform
                    )
            }
        }
        .frame(height: 40)
    }

    private func runVoiceCheck() async {
        AudioClassificationService.shared.stopListening()
        showWaveform = true

        let userName = state.userProfile.name.isEmpty ? "there" : state.userProfile.name
        aiAgent.speakFallDetectionPrompt(userName: userName)

        try? await Task.sleep(for: .seconds(4))

        isListeningForResponse = true
        let result = await audioService.startListening(duration: 5)
        responseText = result.speechDetected ?? ""

        showWaveform = false
        isListeningForResponse = false

        if result.containsDismissal {
            state.dismissFallAlert(outcome: .cancelledByUser)
        } else if result.containsHelpRequest {
            state.activeFallEvent?.voiceResponseReceived = true
            state.activeFallEvent?.voiceResponse = result.speechDetected
            state.dismissFallAlert(outcome: .helpRequested)
            await EmergencyDispatchService.shared.dispatchEmergency(
                event: state.activeFallEvent ?? FallEvent(),
                profile: state.userProfile
            )
        }
    }
}
