import SwiftUI
import CoreMotion
import AVFoundation
import CoreLocation
import Speech

struct OnboardingView: View {
    @Bindable var state: AppState

    @State private var currentStep = 0
    @State private var name = ""
    @State private var ageString = ""
    @State private var conditions = ""
    @State private var contactName = ""
    @State private var contactPhone = ""
    @State private var contactRelationship = ""
    @State private var isCalibrating = false
    @State private var calibrationProgress: Double = 0
    @State private var permissionsGranted = false

    private let totalSteps = 5

    var body: some View {
        ZStack {
            Theme.chassis.ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.top, 60)
                    .padding(.horizontal, 20)

                TabView(selection: $currentStep) {
                    welcomeStep.tag(0)
                    permissionsStep.tag(1)
                    profileStep.tag(2)
                    contactStep.tag(3)
                    calibrationStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(Theme.smoothTransition, value: currentStep)

                navigationButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Progress

    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("SETUP")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Theme.textMuted)
                Spacer()
                Text("STEP \(currentStep + 1)/\(totalSteps)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(Theme.accent)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.recessed)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * CGFloat(currentStep + 1) / CGFloat(totalSteps), height: 6)
                        .animation(Theme.smoothTransition, value: currentStep)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.1))
                        .frame(width: 120, height: 120)
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Theme.accent)
                }

                VStack(spacing: 8) {
                    Text("GUARDIAN")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .tracking(4)
                        .foregroundColor(Theme.textPrimary)

                    Text("AI-Powered Fall Detection")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                }

                VStack(alignment: .leading, spacing: 16) {
                    featureRow(icon: "gyroscope", title: "Motion Sensing", desc: "100Hz gyroscope + accelerometer monitoring")
                    featureRow(icon: "waveform", title: "Audio Verification", desc: "Smart false-positive elimination")
                    featureRow(icon: "brain", title: "Gait Analysis", desc: "Predictive fall risk assessment")
                    featureRow(icon: "phone.arrow.up.right", title: "AI Dispatch", desc: "Autonomous emergency response")
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, 20)
        }
    }

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.chassis)
                    .frame(width: 44, height: 44)
                    .shadow(color: Theme.cardDarkShadow, radius: 4, x: 4, y: 4)
                    .shadow(color: Theme.cardLightShadow, radius: 4, x: -4, y: -4)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(desc)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textMuted)
            }

            Spacer()
        }
    }

    private var permissionsStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 20)

                VStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Theme.accent)
                    Text("Permissions Required")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Guardian needs access to sensors to protect you")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    permissionCard(icon: "gyroscope", title: "Motion & Activity", desc: "Detect falls via gyroscope and accelerometer")
                    permissionCard(icon: "mic", title: "Microphone", desc: "Verify falls with audio analysis")
                    permissionCard(icon: "location", title: "Location", desc: "Share position with emergency services")
                    permissionCard(icon: "waveform", title: "Speech Recognition", desc: "Listen for voice responses")
                    permissionCard(icon: "bell", title: "Notifications", desc: "Alert caregivers of events")
                }
                .padding(.horizontal, 20)

                NeuButton(title: "Grant Permissions", icon: "checkmark.shield", variant: .primary, isFullWidth: true) {
                    Task { await requestAllPermissions() }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
    }

    private func permissionCard(icon: String, title: String, desc: String) -> some View {
        NeuCard(showScrews: false) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(desc)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                }

                Spacer()

                Image(systemName: permissionsGranted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(permissionsGranted ? Theme.ledGreen : Theme.textMuted)
            }
        }
    }

    private var profileStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 20)

                VStack(spacing: 8) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Theme.accent)
                    Text("Your Profile")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }

                VStack(spacing: 16) {
                    NeuInput(placeholder: "Full Name", text: $name, icon: "person")
                    NeuInput(placeholder: "Age", text: $ageString, icon: "calendar")
                    NeuInput(placeholder: "Medical conditions (comma-separated)", text: $conditions, icon: "heart.text.clipboard")
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var contactStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 20)

                VStack(spacing: 8) {
                    Image(systemName: "phone.circle")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Theme.accent)
                    Text("Emergency Contact")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Who should we call if you need help?")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                }

                VStack(spacing: 16) {
                    NeuInput(placeholder: "Contact Name", text: $contactName, icon: "person")
                    NeuInput(placeholder: "Phone Number", text: $contactPhone, icon: "phone")
                    NeuInput(placeholder: "Relationship", text: $contactRelationship, icon: "heart")
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var calibrationStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                ZStack {
                    Circle()
                        .stroke(Theme.recessed, lineWidth: 8)
                        .frame(width: 140, height: 140)

                    Circle()
                        .trim(from: 0, to: calibrationProgress)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.5), value: calibrationProgress)

                    VStack(spacing: 4) {
                        if isCalibrating {
                            Text("\(Int(calibrationProgress * 100))%")
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.accent)
                        } else if calibrationProgress >= 1.0 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Theme.ledGreen)
                        } else {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Theme.accent)
                        }
                    }
                }

                VStack(spacing: 8) {
                    Text(calibrationTitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text(calibrationSubtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.center)
                }

                if isCalibrating {
                    GaitCalibrationLiveSensorsView(state: state)
                        .padding(.horizontal, 4)
                }

                if !isCalibrating && calibrationProgress < 1.0 {
                    NeuButton(title: "Start Calibration", icon: "figure.walk", variant: .primary) {
                        startCalibration()
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var calibrationTitle: String {
        if isCalibrating { return "Calibrating..." }
        if calibrationProgress >= 1.0 { return "Calibration Complete" }
        return "Baseline Walk"
    }

    private var calibrationSubtitle: String {
        if isCalibrating { return "Walk normally for 30 seconds" }
        if calibrationProgress >= 1.0 { return "Your baseline gait has been recorded" }
        return "Walk normally for 30 seconds so we can learn your baseline gait pattern"
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                NeuButton(title: "Back", variant: .ghost) {
                    withAnimation { currentStep -= 1 }
                }
            }

            Spacer()

            if currentStep < totalSteps - 1 {
                NeuButton(title: "Next", icon: "arrow.right", variant: .primary) {
                    saveStepData()
                    withAnimation { currentStep += 1 }
                }
            } else if calibrationProgress >= 1.0 {
                NeuButton(title: "Get Started", icon: "arrow.right", variant: .primary) {
                    completeOnboarding()
                }
            }
        }
    }

    // MARK: - Actions

    private func requestAllPermissions() async {
        LocationService.shared.requestPermission()
        let audioSpeechGranted = await AudioClassificationService.shared.requestPermissions()

        let center = UNUserNotificationCenter.current()
        let notificationsGranted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false

        permissionsGranted = audioSpeechGranted && notificationsGranted
    }

    private func saveStepData() {
        if currentStep == 2 {
            state.userProfile.name = name
            state.userProfile.age = Int(ageString) ?? 0
            state.userProfile.medicalConditions = conditions
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }
        if currentStep == 3 && !contactName.isEmpty {
            let contact = EmergencyContact(
                name: contactName,
                phoneNumber: contactPhone,
                relationship: contactRelationship
            )
            if !state.userProfile.emergencyContacts.contains(where: { $0.name == contactName }) {
                state.userProfile.emergencyContacts.append(contact)
            }
        }
    }

    private func startCalibration() {
        isCalibrating = true
        calibrationProgress = 0

        GaitAnalysisService.shared.beginCalibrationWalk()
        MotionService.shared.startMonitoring(state: state)

        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { timer in
            Task { @MainActor in
                calibrationProgress += 0.01
                if calibrationProgress >= 1.0 {
                    timer.invalidate()
                    isCalibrating = false
                    MotionService.shared.stopMonitoring()

                    if let result = GaitAnalysisService.shared.finalizeCalibrationWalk() {
                        state.userProfile.gaitBaseline = result.baseline
                        state.userProfile.baselineGaitScore = result.record.overallScore
                        state.recordGaitSample(result.record)
                    } else {
                        GaitAnalysisService.shared.cancelCalibrationWalk()
                    }
                }
            }
        }
    }

    private func completeOnboarding() {
        saveStepData()
        withAnimation(Theme.mechanicalEasing) {
            state.userProfile.hasCompletedOnboarding = true
        }
    }
}
