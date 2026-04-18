import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState
    @State private var openAIKey = ""
    @State private var elevenLabsKey = ""
    @State private var k2ThinkKey = ""
    @State private var k2ThinkBaseURL = ""
    @State private var k2ThinkModel = ""

    private var aiConfigured: Bool {
        let hasLLM = !openAIKey.isEmpty || !k2ThinkKey.isEmpty
        return hasLLM && !elevenLabsKey.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileSection
                    contactsSection
                    apiSection
                    detectionSection
                    gaitCalibrationSection
                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Theme.chassis.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.accent)
                        Text("SETTINGS")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .tracking(3)
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
            .onAppear {
                openAIKey = state.openAIKey
                elevenLabsKey = state.elevenLabsKey
                k2ThinkKey = state.k2ThinkAPIKey
                k2ThinkBaseURL = state.k2ThinkBaseURL
                k2ThinkModel = UserDefaults.standard.string(forKey: "k2_think_model") ?? ""
            }
            .overlay {
                if state.isRecalibratingGait {
                    ZStack {
                        Color.black.opacity(0.42).ignoresSafeArea()

                        VStack(spacing: 18) {
                            Text("LIVE GAIT CALIBRATION")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .tracking(2)
                                .foregroundColor(.white.opacity(0.92))

                            Text("Walk normally — we’re recording cadence, acceleration variance, and tilt.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.78))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)

                            GaitCalibrationLiveSensorsView(state: state)

                            ProgressView()
                                .tint(Theme.accent)
                                .scaleEffect(1.15)
                        }
                        .padding(22)
                    }
                    .transition(.opacity)
                }
            }
            .animation(Theme.smoothTransition, value: state.isRecalibratingGait)
        }
    }

    private var profileSection: some View {
        NavigationLink(destination: ProfileSetupView(state: state)) {
            NeuCard(showScrews: false) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Theme.accent.opacity(0.12))
                            .frame(width: 50, height: 50)
                        Text(String(state.userProfile.name.prefix(1)).uppercased())
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.userProfile.name.isEmpty ? "Set up profile" : state.userProfile.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                        Text(state.userProfile.age > 0 ? "Age \(state.userProfile.age)" : "Tap to configure")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textMuted.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var contactsSection: some View {
        NavigationLink(destination: EmergencyContactsView(state: state)) {
            NeuCard(showScrews: false) {
                HStack(spacing: 14) {
                    iconBadge(icon: "phone.fill", color: Theme.ledGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Emergency Contacts")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                        Text("\(state.userProfile.emergencyContacts.count) contact(s)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textMuted.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var apiSection: some View {
        NeuCard(showScrews: true, showVents: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("AI CONFIGURATION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(Theme.textMuted)

                    Spacer()

                    LEDIndicator(
                        status: aiConfigured ? .active : .offline,
                        size: 6,
                        showLabel: false
                    )
                }

                NeuInput(placeholder: "K2 / Kimi API Key (reasoning)", text: $k2ThinkKey, icon: "brain.head.profile", isSecure: true)
                    .onChange(of: k2ThinkKey) { _, newValue in
                        state.k2ThinkAPIKey = newValue
                    }

                NeuInput(
                    placeholder: "K2 base URL (optional, default Moonshot)",
                    text: $k2ThinkBaseURL,
                    icon: "link",
                    isSecure: false
                )
                .onChange(of: k2ThinkBaseURL) { _, newValue in
                    state.k2ThinkBaseURL = newValue
                }

                NeuInput(
                    placeholder: "Model id (empty = \(Constants.API.k2ThinkDefaultModel))",
                    text: $k2ThinkModel,
                    icon: "cpu",
                    isSecure: false
                )
                .onChange(of: k2ThinkModel) { _, newValue in
                    state.k2ThinkModel = newValue
                }

                NeuInput(placeholder: "OpenAI API Key (fallback dispatch copy)", text: $openAIKey, icon: "brain", isSecure: true)
                    .onChange(of: openAIKey) { _, newValue in
                        state.openAIKey = newValue
                    }

                NeuInput(placeholder: "ElevenLabs API Key (TTS + Scribe STT)", text: $elevenLabsKey, icon: "waveform", isSecure: true)
                    .onChange(of: elevenLabsKey) { _, newValue in
                        state.elevenLabsKey = newValue
                    }

                Text("K2 interprets “I need help” vs “I don’t need help” after Scribe transcribes the mic clip. OpenAI is only used if K2 is unset.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.textMuted)

                Text("Never commit API keys. Paste keys here on-device for the demo, or use a local xcconfig that stays gitignored.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.textMuted.opacity(0.8))
            }
        }
    }

    private var detectionSection: some View {
        NeuCard(showScrews: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("DETECTION THRESHOLDS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Theme.textMuted)

                thresholdRow(label: "Gyro Sensitivity", value: "\(Constants.Motion.gyroRotationThreshold) rad/s")
                thresholdRow(label: "Impact Threshold", value: "\(Constants.Motion.impactAccelThreshold) g")
                thresholdRow(label: "Stillness Duration", value: "\(Int(Constants.Motion.stillnessDuration)) sec")
                thresholdRow(label: "Alert Countdown", value: "\(Constants.Alert.countdownDuration) sec")
            }
        }
    }

    private func thresholdRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.accent)
        }
    }

    private var aboutSection: some View {
        NeuCard(showScrews: false) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("GUARDIAN")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text("v1.0")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                }
                Text("AI-Powered Fall Detection & Prevention")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textMuted)
                Text("Princeton Hacks 2026")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.textMuted.opacity(0.7))
            }
        }
    }

    private var gaitCalibrationSection: some View {
        NeuCard(showScrews: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text("GAIT CALIBRATION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Theme.textMuted)

                Text("Walk normally for 45 seconds. We record average cadence, acceleration variance, and phone tilt (gravity) as your baseline, then flag stomping, uneven steps, and forward lean during monitoring.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.textMuted)

                thresholdRow(label: "Baseline saved", value: state.userProfile.gaitBaseline == nil ? "No" : "Yes")
                if let b = state.userProfile.gaitBaseline {
                    thresholdRow(label: "Avg cadence", value: "\(Int(b.avgCadence)) spm")
                    thresholdRow(label: "Accel variance", value: String(format: "%.3f", b.avgAccelVariance))
                    thresholdRow(label: "Avg tilt", value: String(format: "%.0f°", b.avgForwardTiltDegrees))
                }
                thresholdRow(label: "Composite baseline", value: "\(Int(state.userProfile.gaitBaseline?.compositeGaitScore ?? state.userProfile.baselineGaitScore ?? 0))/100")

                NeuButton(
                    title: state.isRecalibratingGait ? "Calibrating..." : "Start Calibration (45 sec)",
                    icon: "figure.walk.motion",
                    variant: .secondary,
                    isFullWidth: true
                ) {
                    guard !state.isRecalibratingGait else { return }
                    Task { await state.recalibrateGaitBaseline(duration: 45) }
                }
            }
        }
    }

    private func iconBadge(icon: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.12))
                .frame(width: 44, height: 44)
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
        }
    }
}
