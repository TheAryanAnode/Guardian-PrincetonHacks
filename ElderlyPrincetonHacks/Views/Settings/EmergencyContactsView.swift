import SwiftUI

struct EmergencyContactsView: View {
    @Bindable var state: AppState

    @State private var newName = ""
    @State private var newPhone = ""
    @State private var newRelationship = ""
    @State private var showAddForm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(state.userProfile.emergencyContacts) { contact in
                    contactCard(contact)
                }

                if showAddForm {
                    addContactForm
                }

                NeuButton(
                    title: showAddForm ? "Cancel" : "Add Contact",
                    icon: showAddForm ? "xmark" : "plus",
                    variant: .secondary,
                    isFullWidth: true
                ) {
                    withAnimation(Theme.smoothTransition) {
                        showAddForm.toggle()
                        if !showAddForm { clearForm() }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Theme.chassis.ignoresSafeArea())
        .navigationTitle("Emergency Contacts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func contactCard(_ contact: EmergencyContact) -> some View {
        NeuCard(showScrews: false) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Text(String(contact.name.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(contact.relationship)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                    Text(contact.phoneNumber)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                }

                Spacer()

                Button {
                    withAnimation {
                        state.userProfile.emergencyContacts.removeAll { $0.id == contact.id }
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.accent)
                }
            }
        }
    }

    private var addContactForm: some View {
        NeuCard(showScrews: true) {
            VStack(alignment: .leading, spacing: 16) {
                Text("NEW CONTACT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Theme.textMuted)

                NeuInput(placeholder: "Name", text: $newName, icon: "person")
                NeuInput(placeholder: "Phone Number", text: $newPhone, icon: "phone")
                NeuInput(placeholder: "Relationship", text: $newRelationship, icon: "heart")

                NeuButton(title: "Save Contact", icon: "checkmark", variant: .primary, isFullWidth: true) {
                    guard !newName.isEmpty, !newPhone.isEmpty else { return }
                    let contact = EmergencyContact(
                        name: newName,
                        phoneNumber: newPhone,
                        relationship: newRelationship
                    )
                    state.userProfile.emergencyContacts.append(contact)
                    clearForm()
                    showAddForm = false
                }
            }
        }
    }

    private func clearForm() {
        newName = ""
        newPhone = ""
        newRelationship = ""
    }
}
