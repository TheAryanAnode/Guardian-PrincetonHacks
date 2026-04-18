import SwiftUI

struct ProfileSetupView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var ageString: String = ""
    @State private var conditions: String = ""
    @State private var medications: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                NeuCard(showScrews: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("PERSONAL INFO")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(Theme.textMuted)

                        NeuInput(placeholder: "Full Name", text: $name, icon: "person")
                        NeuInput(placeholder: "Age", text: $ageString, icon: "calendar")
                    }
                }

                NeuCard(showScrews: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("MEDICAL INFO")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(Theme.textMuted)

                        NeuInput(placeholder: "Conditions (comma-separated)", text: $conditions, icon: "heart.text.clipboard")
                        NeuInput(placeholder: "Medications (comma-separated)", text: $medications, icon: "pills")
                    }
                }

                NeuButton(title: "Save Profile", icon: "checkmark", variant: .primary, isFullWidth: true) {
                    saveProfile()
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Theme.chassis.ignoresSafeArea())
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadCurrent() }
    }

    private func loadCurrent() {
        name = state.userProfile.name
        ageString = state.userProfile.age > 0 ? "\(state.userProfile.age)" : ""
        conditions = state.userProfile.medicalConditions.joined(separator: ", ")
        medications = state.userProfile.medications.joined(separator: ", ")
    }

    private func saveProfile() {
        state.userProfile.name = name
        state.userProfile.age = Int(ageString) ?? 0
        state.userProfile.medicalConditions = conditions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        state.userProfile.medications = medications.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        dismiss()
    }
}
