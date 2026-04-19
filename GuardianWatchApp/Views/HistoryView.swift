import SwiftUI

/// Replaces the iOS Caregiver dashboard. We keep the chart-y data off the
/// watch (too small) and present a tappable List of recent fall events.
struct HistoryView: View {
    @Bindable var state: AppState

    var body: some View {
        Group {
            if state.fallHistory.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(state.fallHistory) { event in
                        NavigationLink(value: event) { row(event) }
                    }
                }
                .listStyle(.carousel)
                .navigationDestination(for: FallEvent.self) { event in
                    FallDetailView(event: event)
                }
            }
        }
        .containerBackground(Theme.background.gradient, for: .tabView)
        .navigationTitle("Falls")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 30))
                .foregroundStyle(Theme.ledGreen)
            Text("No events")
                .font(.headline)
            Text("All clear")
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
        }
        .padding()
    }

    private func row(_ event: FallEvent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(rowColor(event.outcome))
                    .frame(width: 8, height: 8)
                Text(event.outcome?.rawValue ?? "Pending")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(event.severity.rawValue)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.accentSoft, in: Capsule())
                    .foregroundStyle(Theme.accent)
            }
            Text(event.timestamp.compactDisplay)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.vertical, 2)
    }

    private func rowColor(_ outcome: FallOutcome?) -> Color {
        switch outcome {
        case .cancelledByUser, .falseAlarm:           return Theme.ledGreen
        case .helpRequested, .emergencyDispatched:    return Theme.ledRed
        case .noResponse:                             return Theme.ledYellow
        case nil:                                     return Theme.textMuted
        }
    }
}

struct FallDetailView: View {
    let event: FallEvent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header

                WatchCard {
                    Text("TRIGGERS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textMuted)
                    ForEach(event.triggers) { trigger in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: trigger.icon)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(trigger.description)
                                    .font(.system(size: 12, weight: .medium))
                                Text(trigger.value)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                WatchCard {
                    Text("TIMELINE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textMuted)
                    ForEach(event.timelineEntries) { entry in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.event)
                                .font(.system(size: 12, weight: .semibold))
                            Text("\(entry.timestamp.shortTimestamp) · \(entry.detail)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.textMuted)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle("Event")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.outcome?.rawValue ?? "Pending")
                .font(.system(size: 16, weight: .bold))
            Text(event.timestamp.compactDisplay)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.textMuted)
        }
    }
}
