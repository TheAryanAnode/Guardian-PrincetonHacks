import SwiftUI
import MapKit

struct FallDetailView: View {
    let event: FallEvent

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                severityHeader
                sensorDataPanel
                triggersList
                timelineSection

                if let lat = event.latitude, let lon = event.longitude {
                    locationSection(lat: lat, lon: lon)
                }

                outcomePanel
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Theme.chassis.ignoresSafeArea())
        .navigationTitle("Event Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var severityHeader: some View {
        NeuCard(showScrews: true, showVents: true) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(severityColor)
                            .frame(width: 12, height: 12)
                            .shadow(color: severityColor.opacity(0.6), radius: 4)

                        Text(event.severity.rawValue.uppercased())
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(severityColor)
                    }

                    Text(event.timestamp.mediumDisplay)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                }

                Spacer()

                if let outcome = event.outcome {
                    Text(outcome.rawValue)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(outcomeColor(outcome).opacity(0.15))
                        .foregroundColor(outcomeColor(outcome))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var sensorDataPanel: some View {
        NeuCard(showScrews: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("SENSOR DATA")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Theme.textMuted)

                HStack(spacing: 16) {
                    dataMetric(label: "PEAK GYRO", value: event.peakGyro.oneDecimal, unit: "rad/s")
                    dataMetric(label: "IMPACT", value: event.peakAcceleration.oneDecimal, unit: "g")
                    dataMetric(label: "STILLNESS", value: "\(Int(event.stillnessDuration))", unit: "sec")
                    if let conf = event.audioConfidence {
                        dataMetric(label: "AUDIO", value: "\(Int(conf * 100))", unit: "%")
                    }
                }
            }
        }
    }

    private func dataMetric(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(Theme.textMuted)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                Text(unit)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var triggersList: some View {
        FallReasonView(triggers: event.triggers)
            .padding(.horizontal, 4)
    }

    private var timelineSection: some View {
        NeuCard(showScrews: true) {
            VStack(alignment: .leading, spacing: 12) {
                Text("EVENT TIMELINE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Theme.textMuted)

                ForEach(Array(event.timelineEntries.enumerated()), id: \.element.id) { index, entry in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(index == event.timelineEntries.count - 1 ? Theme.accent : Theme.borderDark)
                                .frame(width: 10, height: 10)

                            if index < event.timelineEntries.count - 1 {
                                Rectangle()
                                    .fill(Theme.borderDark.opacity(0.5))
                                    .frame(width: 2, height: 30)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.event)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                            Text(entry.detail)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.textMuted)
                            Text(entry.timestamp.shortTimestamp)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(Theme.textMuted.opacity(0.7))
                        }

                        Spacer()
                    }
                }
            }
        }
    }

    private func locationSection(lat: Double, lon: Double) -> some View {
        NeuCard(showScrews: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text("LOCATION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Theme.textMuted)

                Map(initialPosition: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))) {
                    Marker("Fall Location", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        .tint(.red)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))

                Text(String(format: "%.4f, %.4f", lat, lon))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
            }
        }
    }

    private var outcomePanel: some View {
        Group {
            if let outcome = event.outcome {
                NeuCard(showScrews: false) {
                    HStack(spacing: 12) {
                        Image(systemName: outcomeIcon(outcome))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(outcomeColor(outcome))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("OUTCOME")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.5)
                                .foregroundColor(Theme.textMuted)
                            Text(outcome.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                        }

                        Spacer()

                        if event.voiceResponseReceived, let response = event.voiceResponse {
                            Text("\"\(response)\"")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.textMuted)
                                .italic()
                        }
                    }
                }
            }
        }
    }

    private var severityColor: Color {
        switch event.severity {
        case .low:      return Theme.ledGreen
        case .medium:   return Theme.ledYellow
        case .high:     return Theme.accent
        case .critical: return Theme.accent
        }
    }

    private func outcomeColor(_ outcome: FallOutcome) -> Color {
        switch outcome {
        case .cancelledByUser, .falseAlarm: return Theme.ledGreen
        case .helpRequested, .emergencyDispatched: return Theme.accent
        case .noResponse: return Theme.ledYellow
        }
    }

    private func outcomeIcon(_ outcome: FallOutcome) -> String {
        switch outcome {
        case .cancelledByUser: return "checkmark.circle"
        case .falseAlarm:      return "xmark.circle"
        case .helpRequested:   return "phone.arrow.up.right"
        case .emergencyDispatched: return "light.beacon.max"
        case .noResponse:      return "exclamationmark.triangle"
        }
    }
}
