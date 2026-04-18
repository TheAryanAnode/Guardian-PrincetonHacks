import Foundation
import UIKit
import Combine
import CoreLocation

@MainActor
final class EmergencyDispatchService: ObservableObject {
    static let shared = EmergencyDispatchService()

    @Published var isDispatching = false
    @Published var dispatchStatus = ""

    private init() {}

    func dispatchEmergency(event: FallEvent, profile: UserProfile) async {
        isDispatching = true
        dispatchStatus = "Initiating emergency dispatch..."
        LiveActivityManager.shared.updateActivity(
            status: .dispatching,
            gaitScore: Int(event.peakAcceleration * 20),
            alertActive: true,
            countdown: 0
        )

        LocationService.shared.requestLocation()
        try? await Task.sleep(for: .seconds(1))

        let location = LocationService.shared.coordinateString

        var updatedEvent = event
        updatedEvent.latitude = LocationService.shared.currentLocation?.coordinate.latitude
        updatedEvent.longitude = LocationService.shared.currentLocation?.coordinate.longitude

        dispatchStatus = "Generating emergency message..."
        let message = await AIAgentService.shared.generateContextualMessage(
            event: updatedEvent,
            profile: profile,
            location: location
        )

        dispatchStatus = "Speaking emergency alert..."
        let elevenKey = UserDefaults.standard.string(forKey: "elevenlabs_key") ?? ""
        if !elevenKey.isEmpty {
            await AIAgentService.shared.speakWithElevenLabs(message)
        } else {
            AIAgentService.shared.speakPrompt(message)
            try? await Task.sleep(for: .seconds(3))
        }

        dispatchStatus = "Calling emergency contact..."
        callEmergencyNumber()

        updatedEvent.timelineEntries.append(
            TimelineEntry(event: "Emergency Dispatched", detail: "Called \(Constants.Emergency.placeholderPhoneNumber)")
        )

        dispatchStatus = "Emergency services contacted"
        isDispatching = false
        LiveActivityManager.shared.updateActivity(
            status: .active,
            gaitScore: Int(profile.baselineGaitScore ?? 0),
            alertActive: false,
            countdown: nil
        )
    }

    func callEmergencyNumber() {
        guard let url = URL(string: Constants.Emergency.phoneURL) else { return }
        UIApplication.shared.open(url)
    }

    func notifyEmergencyContacts(profile: UserProfile, event: FallEvent) {
        for contact in profile.emergencyContacts {
            let message = """
            FALL ALERT: \(profile.name) may have fallen. \
            Severity: \(event.severity.rawValue). \
            Location: \(LocationService.shared.coordinateString). \
            Please check on them immediately.
            """

            let smsURL = "sms:\(contact.phoneNumber)&body=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            if let url = URL(string: smsURL) {
                UIApplication.shared.open(url)
            }
        }
    }
}
