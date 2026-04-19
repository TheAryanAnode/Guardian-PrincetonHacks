import Foundation
import WatchKit
import Combine

/// On watchOS we can't call `UIApplication.shared.open` — instead we use
/// `WKExtension.shared().openSystemURL(_:)` for `tel:` and `sms:` URLs.
/// On a cellular Apple Watch this places the call directly; on a paired
/// non-cellular Watch it relays to the iPhone.
@MainActor
final class EmergencyDispatchService: ObservableObject {
    static let shared = EmergencyDispatchService()

    @Published var isDispatching = false
    @Published var dispatchStatus = ""

    private init() {}

    func dispatchEmergency(event: FallEvent, profile: UserProfile) async {
        isDispatching = true
        dispatchStatus = "Initiating emergency dispatch…"
        HapticsService.dispatchTriggered()

        LocationService.shared.requestLocation()
        try? await Task.sleep(for: .seconds(1))

        let location = LocationService.shared.coordinateString
        var updatedEvent = event
        updatedEvent.latitude = LocationService.shared.currentLocation?.coordinate.latitude
        updatedEvent.longitude = LocationService.shared.currentLocation?.coordinate.longitude

        dispatchStatus = "Generating emergency message…"
        let message = await AIAgentService.shared.generateContextualMessage(
            event: updatedEvent,
            profile: profile,
            location: location
        )

        dispatchStatus = "Speaking emergency alert…"
        AIAgentService.shared.speakPrompt(message)
        try? await Task.sleep(for: .seconds(2))

        dispatchStatus = "Calling emergency contact…"
        callEmergencyNumber()

        updatedEvent.timelineEntries.append(
            TimelineEntry(event: "Emergency Dispatched", detail: "Called \(Constants.Emergency.placeholderPhoneNumber)")
        )

        dispatchStatus = "Emergency services contacted"
        isDispatching = false
    }

    func callEmergencyNumber() {
        // Demo guard: don't dial a real number on stage.
        if Constants.Demo.suppressRealPhoneCalls {
            print("[Guardian-DEMO] Suppressed call to \(Constants.Emergency.placeholderPhoneNumber)")
            return
        }
        guard let url = URL(string: Constants.Emergency.phoneURL) else { return }
        WKExtension.shared().openSystemURL(url)
    }

    /// Watch can also send SMS via the paired iPhone.
    func notifyEmergencyContacts(profile: UserProfile, event: FallEvent) {
        if Constants.Demo.suppressRealPhoneCalls {
            print("[Guardian-DEMO] Would SMS \(profile.emergencyContacts.count) contacts.")
            return
        }
        for contact in profile.emergencyContacts {
            let body = "FALL ALERT: \(profile.name) may have fallen. Severity: \(event.severity.rawValue). Location: \(LocationService.shared.coordinateString)."
            let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let smsString = "\(Constants.Emergency.smsURLBase)\(contact.phoneNumber)&body=\(encoded)"
            if let url = URL(string: smsString) {
                WKExtension.shared().openSystemURL(url)
            }
        }
    }
}
