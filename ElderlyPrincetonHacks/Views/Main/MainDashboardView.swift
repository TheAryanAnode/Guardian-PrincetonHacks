import SwiftUI
import Charts

struct MainDashboardView: View {
    @Bindable var state: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    StatusPanelView(state: state)
                    monitoringToggle
                    weeklyFallsSection
                    GaitLiveInsightCard(state: state)
                    GaitTrendView(state: state)
                    recentEventsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Theme.chassis.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.accent)
                        Text("GUARDIAN")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .tracking(3)
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        NeuCard(showScrews: false, showVents: false) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome back,")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                    Text(state.userProfile.name.isEmpty ? "User" : state.userProfile.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    LEDIndicator(
                        status: state.isMonitoring ? .active : .offline,
                        size: 10
                    )

                    Text(state.isMonitoring ? "Protected" : "Inactive")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(state.isMonitoring ? Theme.ledGreen : Theme.textMuted)
                }
            }
        }
    }

    private var monitoringToggle: some View {
        NeuCard(showScrews: false) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FALL DETECTION")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(Theme.textMuted)

                        Text(state.isMonitoring ? "Sensors active at 100 Hz" : "Tap to activate monitoring")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                    }

                    Spacer()

                    NeuButton(
                        title: state.isMonitoring ? "Stop" : "Start",
                        icon: state.isMonitoring ? "stop.fill" : "play.fill",
                        variant: state.isMonitoring ? .secondary : .primary
                    ) {
                        withAnimation(Theme.mechanicalEasing) {
                            state.isMonitoring.toggle()
                            if state.isMonitoring {
                                MotionService.shared.startMonitoring(state: state)
                            } else {
                                MotionService.shared.stopMonitoring()
                            }
                        }
                    }
                }

                if state.isMonitoring {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.text.clipboard")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(state.gaitRiskLevel.ledStatus.color)
                        Text("GAIT STATUS: \(state.gaitStatusText.uppercased())")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(state.gaitRiskLevel.ledStatus.color)
                        Spacer()
                    }
                }
            }
        }
    }

    private var weeklyFallsSection: some View {
        NeuCard(showScrews: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text("WEEKLY FALLS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Theme.textMuted)

                Chart(state.weeklyFallCounts) { bucket in
                    BarMark(
                        x: .value("Week", bucket.label),
                        y: .value("Falls", bucket.count)
                    )
                    .foregroundStyle(Theme.accent)
                    .cornerRadius(4)
                }
                .frame(height: 140)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
    }

    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RECENT EVENTS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Theme.textMuted)

                Spacer()

                Text("\(state.fallHistory.count) total")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
            }
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
                            Text("All clear -- monitoring active")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.textMuted)
                        }

                        Spacer()
                    }
                }
            } else {
                ForEach(state.fallHistory.prefix(3)) { event in
                    eventRow(event)
                }
            }
        }
    }

    private func eventRow(_ event: FallEvent) -> some View {
        NeuCard(showScrews: false) {
            HStack(spacing: 12) {
                Circle()
                    .fill(outcomeColor(event.outcome))
                    .frame(width: 10, height: 10)
                    .shadow(color: outcomeColor(event.outcome).opacity(0.5), radius: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.outcome?.rawValue ?? "Pending")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(event.timestamp.mediumDisplay)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(event.severity.rawValue)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(Theme.accent)
                    Text("\(event.peakGyro.oneDecimal) rad/s")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                }
            }
        }
    }

    private func outcomeColor(_ outcome: FallOutcome?) -> Color {
        switch outcome {
        case .cancelledByUser, .falseAlarm: return Theme.ledGreen
        case .helpRequested, .emergencyDispatched: return Theme.ledRed
        case .noResponse: return Theme.ledYellow
        case nil: return Theme.textMuted
        }
    }
}
