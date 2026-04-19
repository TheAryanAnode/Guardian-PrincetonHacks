import SwiftUI

/// Settings on the watch are intentionally minimal — heavy editing happens
/// on the paired iPhone. We expose: profile name, contact list, baseline
/// status, and a recalibrate button.
struct SettingsView: View {
    @Bindable var state: AppState

    var body: some View {
        List {
            Section("Profile") {
                NavigationLink {
                    ProfileEditView(state: state)
                } label: {
                    HStack {
                        Text(state.userProfile.name.isEmpty ? "Set name" : state.userProfile.name)
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        if state.userProfile.age > 0 {
                            Text("Age \(state.userProfile.age)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                }
            }

            Section("Emergency Contacts") {
                if state.userProfile.emergencyContacts.isEmpty {
                    Text("Add contacts on iPhone")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                } else {
                    ForEach(state.userProfile.emergencyContacts) { contact in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(contact.name)
                                .font(.system(size: 13, weight: .semibold))
                            Text(contact.phoneNumber)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                }
            }

            Section("Gait baseline") {
                HStack {
                    Text("Saved")
                    Spacer()
                    Text(state.userProfile.gaitBaseline == nil ? "No" : "Yes")
                        .foregroundStyle(state.userProfile.gaitBaseline == nil ? Theme.textMuted : Theme.ledGreen)
                }
                .font(.system(size: 12, weight: .semibold))
            }

            Section("Detection thresholds") {
                thresholdRow("Gyro",  "\(Constants.Motion.gyroRotationThreshold) rad/s")
                thresholdRow("Impact","\(Constants.Motion.impactAccelThreshold) g")
                thresholdRow("Stillness","\(Int(Constants.Motion.stillnessDuration))s")
                thresholdRow("Countdown","\(Constants.Alert.countdownDuration)s")
            }

            Section("About") {
                Text("Guardian v1.0")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .listStyle(.carousel)
        .containerBackground(Theme.background.gradient, for: .tabView)
        .navigationTitle("Settings")
    }

    private func thresholdRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.accent)
        }
    }
}

/// Edits name + age via watch text input controllers (the watch keyboard /
/// dictation / Scribble — all surfaced by `.textFieldStyle(.plain)` in SwiftUI).
struct ProfileEditView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var ageString = ""

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $name)
            }
            Section("Age") {
                TextField("Age", text: $ageString)
            }
            Button("Save") {
                state.userProfile.name = name
                state.userProfile.age = Int(ageString) ?? 0
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .navigationTitle("Profile")
        .onAppear {
            name = state.userProfile.name
            ageString = state.userProfile.age > 0 ? "\(state.userProfile.age)" : ""
        }
    }
}
