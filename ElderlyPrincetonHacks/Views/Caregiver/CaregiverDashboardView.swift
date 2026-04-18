import SwiftUI
import Charts

struct CaregiverDashboardView: View {
    @Bindable var state: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    patientStatusCard
                    statsStrip
                    weeklyFallsSection
                    eventFeed
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Theme.chassis.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.accent)
                        Text("CAREGIVER")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .tracking(3)
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
        }
    }

    private var patientStatusCard: some View {
        NeuCard(showScrews: true, showVents: true) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PATIENT STATUS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(Theme.textMuted)

                        Text(state.userProfile.name.isEmpty ? "User" : state.userProfile.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                    }

                    Spacer()

                    LEDIndicator(
                        status: state.isMonitoring ? .active : .offline,
                        size: 12
                    )
                }

                HStack(spacing: 0) {
                    patientMetric(
                        icon: "figure.walk",
                        label: "GAIT SCORE",
                        value: "\(Int(state.currentGaitScore))/100",
                        color: state.gaitRiskLevel.ledStatus.color
                    )

                    divider

                    patientMetric(
                        icon: "clock",
                        label: "MONITORING",
                        value: state.isMonitoring ? "Active" : "Off",
                        color: state.isMonitoring ? Theme.ledGreen : Theme.textMuted
                    )

                    divider

                    patientMetric(
                        icon: "exclamationmark.triangle",
                        label: "EVENTS",
                        value: "\(state.fallHistory.count)",
                        color: state.fallHistory.isEmpty ? Theme.ledGreen : Theme.ledYellow
                    )
                }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.borderDark.opacity(0.3))
            .frame(width: 1, height: 50)
    }

    private func patientMetric(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textPrimary)

            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var statsStrip: some View {
        NeuCard(showScrews: false) {
            HStack(spacing: 16) {
                statBadge(
                    label: "FALSE ALARMS",
                    count: state.fallHistory.filter { $0.outcome == .falseAlarm || $0.outcome == .cancelledByUser }.count,
                    color: Theme.ledGreen
                )
                statBadge(
                    label: "HELP CALLS",
                    count: state.fallHistory.filter { $0.outcome == .helpRequested }.count,
                    color: Theme.ledYellow
                )
                statBadge(
                    label: "EMERGENCY",
                    count: state.fallHistory.filter { $0.outcome == .emergencyDispatched || $0.outcome == .noResponse }.count,
                    color: Theme.accent
                )
            }
        }
    }

    private func statBadge(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(Theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var eventFeed: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EVENT HISTORY")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(Theme.textMuted)
                .padding(.horizontal, 4)

            if state.fallHistory.isEmpty {
                NeuCard(showScrews: false) {
                    HStack {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.ledGreen)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("No events recorded")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                            Text("Patient safety log is clean")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.textMuted)
                        }
                        Spacer()
                    }
                }
            } else {
                ForEach(state.fallHistory) { event in
                    NavigationLink(destination: FallDetailView(event: event)) {
                        eventCard(event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var weeklyFallsSection: some View {
        NeuCard(showScrews: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text("WEEKLY FALL FREQUENCY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Theme.textMuted)

                Chart(state.weeklyFallCounts) { bucket in
                    LineMark(
                        x: .value("Week", bucket.weekStart),
                        y: .value("Falls", bucket.count)
                    )
                    .foregroundStyle(Theme.accent)
                    .lineStyle(.init(lineWidth: 2))

                    PointMark(
                        x: .value("Week", bucket.weekStart),
                        y: .value("Falls", bucket.count)
                    )
                    .foregroundStyle(Theme.ledGreen)
                }
                .frame(height: 130)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
            }
        }
    }

    private func eventCard(_ event: FallEvent) -> some View {
        NeuCard(showScrews: false) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Circle()
                        .fill(eventDotColor(event.outcome))
                        .frame(width: 12, height: 12)
                        .shadow(color: eventDotColor(event.outcome).opacity(0.5), radius: 3)

                    if event.outcome == .emergencyDispatched || event.outcome == .noResponse {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.outcome?.rawValue ?? "Pending")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    Text(event.timestamp.mediumDisplay)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textMuted)

                    if event.voiceResponseReceived {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                                .font(.system(size: 9))
                            Text("Voice response received")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(Theme.textMuted)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(event.severity.rawValue)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.12))
                        .foregroundColor(Theme.accent)
                        .clipShape(Capsule())

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textMuted.opacity(0.5))
                }
            }
        }
    }

    private func eventDotColor(_ outcome: FallOutcome?) -> Color {
        switch outcome {
        case .cancelledByUser, .falseAlarm: return Theme.ledGreen
        case .helpRequested, .emergencyDispatched: return Theme.accent
        case .noResponse: return Theme.ledYellow
        case nil: return Theme.textMuted
        }
    }
}
