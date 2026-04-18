import SwiftUI

struct FallConfirmationView: View {
    @Bindable var state: AppState
    @StateObject private var audioService = AudioClassificationService.shared
    @StateObject private var aiAgent = AIAgentService.shared

    @State private var isListeningForResponse = false
    @State private var responseText = ""
    @State private var showWaveform = false
    @State private var hasRunVoiceCheck = false
    @State private var k2Assessment: CrisisVoiceAssessment?

    var fallEvent: FallEvent

    var body: some View {
        VStack(spacing: 20) {
            waveformIndicator

            VStack(spacing: 8) {
                Text(statusLabel)
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

            if let k2 = k2Assessment {
                NeuCard(showScrews: true, showVents: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(Theme.accent)
                            Text("K2 SAFETY REASONING")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1.5)
                                .foregroundColor(Theme.textMuted)
                            Spacer()
                            Text(k2.intent.rawValue.replacingOccurrences(of: "_", with: " ").uppercased())
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.darkSlate)
                        }

                        Text(k2.reasoningSummary)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.textPrimary)

                        Divider().opacity(0.25)

                        Text("Caregiver brief")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                        Text(k2.caregiverBrief)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.textMuted)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(Theme.smoothTransition, value: k2Assessment != nil)
        .task {
            guard !hasRunVoiceCheck else { return }
            hasRunVoiceCheck = true
            await runVoiceCheck()
        }
    }

    private var statusLabel: String {
        if aiAgent.isSpeaking { return "SPEAKING…" }
        if isListeningForResponse { return "LISTENING…" }
        if k2Assessment != nil { return "REASONING COMPLETE" }
        return "PROCESSING…"
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
        k2Assessment = nil

        let fallSnapshot = fallEvent
        let userName = state.userProfile.name.isEmpty ? "there" : state.userProfile.name
        await aiAgent.speakFallCheckPromptAsync(userName: userName)

        isListeningForResponse = true
        let result = await audioService.startListening(duration: 5)
        let transcript = result.speechDetected?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        responseText = transcript

        showWaveform = false
        isListeningForResponse = false

        let k2Key = state.k2ThinkAPIKey
        if !k2Key.isEmpty, !transcript.isEmpty {
            let base = state.k2ThinkBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? Constants.API.k2ThinkDefaultBaseURL
                : state.k2ThinkBaseURL
            let model = state.resolvedK2ThinkModel
            if let parsed = await CrisisReasoningService.assessVoiceResponse(
                transcript: transcript,
                fall: fallSnapshot,
                profile: state.userProfile,
                apiKey: k2Key,
                baseURL: base,
                model: model
            ) {
                k2Assessment = parsed
                if !parsed.spokenGuidance.isEmpty {
                    await aiAgent.speakWithElevenLabs(parsed.spokenGuidance)
                }
            }
        }

        if let k2 = k2Assessment, k2.confidence >= 0.62 {
            switch k2.intent {
            case .all_clear:
                state.dismissFallAlert(outcome: .falseAlarm)
                return
            case .help_needed:
                var updated = fallSnapshot
                updated.voiceResponseReceived = true
                updated.voiceResponse = transcript
                state.dismissFallAlert(outcome: .helpRequested)
                await EmergencyDispatchService.shared.dispatchEmergency(
                    event: updated,
                    profile: state.userProfile
                )
                return
            case .uncertain:
                break
            }
        }

        if result.containsDismissal {
            state.dismissFallAlert(outcome: .cancelledByUser)
            return
        }

        if result.containsHelpRequest {
            var updated = fallSnapshot
            updated.voiceResponseReceived = true
            updated.voiceResponse = transcript
            state.dismissFallAlert(outcome: .helpRequested)
            await EmergencyDispatchService.shared.dispatchEmergency(
                event: updated,
                profile: state.userProfile
            )
        }
    }
}
