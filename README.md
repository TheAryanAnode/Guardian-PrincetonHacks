# Guardian

A fall-detection and safety companion for elderly users, built for **Princeton Hacks**. Runs natively on the Apple Watch as the primary monitor, with an iPhone companion that handles the heavier work — Firestore sync, Live Activities, audio analysis, and the AI-driven crisis reasoning layer.

The pitch is simple: someone falls, the watch knows about it within a couple of seconds, gives them thirty seconds to say they're fine, and if they don't, it dials a contact and pushes the incident — with location, sensor trace, severity, and medical context — to the cloud where a caregiver or emergency contact can see it.

We tried to do this with the constraints that actually matter for the people who'd use it: it has to work without unlocking the phone, it has to keep working when the watch is off-wrist or the wearer is unconscious, and the UI has to be readable by someone whose eyesight isn't what it used to be. No swipe gestures, no thin gray text, no clever animations. Big tap targets. Loud haptics. A voice that tells you what's happening.

---

## What's in the repo

There are two apps and one shared brain.

| Target | Platform | Role |
|---|---|---|
| `ElderlyPrincetonHacks` | iOS 26+ | Companion app. Runs the heavy services (Firebase REST, audio classification, K2 Think LLM calls, ElevenLabs voice transcription), shows the caregiver-facing dashboards, and is the bridge to the cloud. |
| `GuardianWatch Watch App` | watchOS 26+ | The actual safety device. Lives on the wrist. Handles fall detection, gait monitoring, the alert UX, and emergency dispatch. Falls through to the iPhone for cloud writes. |
| `GuardianLiveActivityExtension` | iOS 26+ widget extension | Lock-screen Live Activity that surfaces an active fall countdown and current monitoring state. Can be left disabled if you're signing with a Personal Team. |

The watch app is a clean rewrite of the iOS app — pure SwiftUI, no UIKit, redesigned for a 41/45mm display with high contrast, vertical scrolling, and large type. It is **not** a Watch Connectivity-style "remote control" of the iPhone. It runs independently on the watch and only talks to the phone when it has something to upload.

---

## How fall detection actually works

There is no magic here. We're not running a neural net on the wrist. The detection pipeline is:

1. **Continuous sample at 50 Hz** from `CMMotionManager.deviceMotion` while monitoring is on. We track:
    - User acceleration magnitude (gravity removed)
    - Rotation rate magnitude (gyroscope)
    - Tilt vs gravity (the angle of the wrist relative to vertical)
2. **Two-stage trigger.** A candidate fall fires when *both*:
    - Acceleration spikes above a threshold (default ~3.0 g for a fast forward fall)
    - Rotation rate also spikes above its threshold within the same window
   This rejects most everyday wrist flips, hand-claps, and steering-wheel motions, which produce one signal but not the other.
3. **Stillness gate.** After the spike, we look at the next ~2.5 seconds. If the wrist is still moving normally, we drop the candidate. If the wearer is still — meaning low acceleration variance and a tilt that suggests the watch is now horizontal — we promote it to a confirmed fall.
4. **Alert phase.** A full-screen modal takes over the watch. AVSpeechSynthesizer says, through the watch speaker, "I detected a possible fall. Tap *Get Help* if you need help, or tap *I'm OK* if you want to cancel." Haptic notifications fire on a 1 Hz heartbeat that escalates as the countdown drops below 10 seconds. The voice prompt repeats every 10 seconds.
5. **Resolution.** The wearer has 30 seconds (configurable in `Constants.swift`) to tap one of the two buttons. If they tap *I'm OK*, the event is recorded as `cancelledByUser` and that's the end of it. If they tap *Get Help*, or the timer expires with no input, the watch opens `tel://` to the configured emergency contact via `WKExtension.openSystemURL`, and the event is queued for upload.

For the gait side: during onboarding the wearer takes a one-minute calibration walk. We capture cadence, acceleration variance, and tilt-vs-gravity stability into a `GaitBaseline`. When monitoring is on, we score the live signal against that baseline and surface a "live AI insight" — basically a deviation score with plain-English flags ("more shuffle than usual today", "less knee lift"). It is intended as a soft signal, not a diagnostic.

---

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                     Apple Watch                       │
│                                                       │
│   CoreMotion → FallDetectionEngine → FallAlertView    │
│                          │                            │
│              GaitAnalysisService                      │
│                          │                            │
│              HKWorkoutSession (keeps app alive)       │
│                          │                            │
│                  AppState ◄────────┐                  │
│                          │         │                  │
│   AVSpeechSynthesizer ◄──┘         │                  │
│   WatchKit Haptics ◄───────────────┤                  │
│   WKExtension.openSystemURL("tel:") ┘                 │
│                          │                            │
│             WatchConnectivityService ─── transferUserInfo
│                                                       │
└──────────────────────────────────────────────────────┘
                         │
                         ▼  (queued, guaranteed delivery)
┌──────────────────────────────────────────────────────┐
│                       iPhone                          │
│                                                       │
│   WatchConnectivityService.didReceiveUserInfo         │
│                          │                            │
│              FallFirestoreService                     │
│                          │                            │
│                  Firebase REST API                    │
│              (anonymous auth, no SDK)                 │
│                          │                            │
└──────────────────────────┼───────────────────────────┘
                           ▼
                ┌──────────────────────┐
                │   Cloud Firestore    │
                │   fall_events/<id>   │
                └──────────────────────┘
```

The iPhone runs its own independent fall-detection pipeline (same logic, different sensor source — phone-in-pocket or phone-on-table use cases), plus the heavier stack: K2 Think LLM-driven crisis reasoning, ElevenLabs streaming transcription, audio scene classification (was that a thump or a laugh?), Live Activities, and the caregiver dashboards.

A few things worth calling out about the design:

- **No Firebase SDK on the watch.** We deliberately did not bring `FirebaseFirestore.framework` onto watchOS. It's a multi-megabyte dependency and the watch is bandwidth- and battery-constrained. Instead, the watch does its detection locally and hands off to the phone when reachable. If the phone is dead or the watch is offline, `WCSession.transferUserInfo` queues the payload to disk and delivers it the moment the iPhone next wakes — minutes, hours, doesn't matter.
- **Firebase REST, not the Firebase iOS SDK, on iPhone either.** Same logic: avoid the binary bloat. `FallFirestoreService` does anonymous-auth + `firestore.googleapis.com/v1/projects/...` POSTs by hand. ~250 lines of Swift, no Swift Package, build time stays under 10 seconds.
- **HKWorkoutSession is the trick that keeps monitoring alive.** WatchOS will suspend a normal app within seconds of the wrist dropping. A workout session — even one we configure ourselves with `.other` activity type — is the supported primitive for "let me run continuously and read sensors." We start one when monitoring engages and end it when the wearer disables monitoring.
- **Live Activities on iPhone are optional.** They give a nice lock-screen pill that shows monitoring state and active countdowns, but they're a separate signed extension target. If you're on a free Personal Team and don't want to deal with extra provisioning, you can leave that target out — the main app already detects this and downgrades gracefully.

---

## Setup

You need:

- A Mac with **Xcode 26.4** or later
- An **Apple Developer account** (free Personal Team is fine)
- An **iPhone running iOS 26.3+** and an **Apple Watch running watchOS 26.3+**, paired
- A USB-C cable for the iPhone (Apple Watch installs go through the iPhone — you don't need to plug the watch in)

### First-time signing setup

This part is annoying and there is no way around it. Apple's signing flow assumes you have a paid developer account; with a free Personal Team you have to make peace with three things:

1. **Bundle identifiers must be unique.** Right now everything is namespaced under `com.pulkitchaudhary.guardian.*`. Apple will not let you sign anything with someone else's namespace. Open the project in Xcode and, for each of the three targets, change the bundle identifier under **Signing & Capabilities → Bundle Identifier** to something with your own prefix — e.g. `com.yourname.guardian`, `com.yourname.guardian.watchkitapp`, `com.yourname.guardian.GuardianLiveActivity`. Keep the suffixes (`watchkitapp`, `GuardianLiveActivity`) intact.
2. **Pick your team.** Same screen, **Team** dropdown. Choose your Personal Team for all three targets.
3. **HealthKit's "Verifiable Health Records" capability does not work on Personal Teams.** We've already removed it from the entitlements file — if Xcode tries to add it back automatically, just disable that one row in Signing & Capabilities. Leaving plain HealthKit access enabled is fine and what we need.

If the iOS app fails to install with a `CoreDeviceError 3002`, it's almost always one of those three. The Apple Watch will **not** install through Xcode in this state because Xcode insists on installing the iPhone companion first. That's what `install-to-watch.sh` is for.

### Firebase

There's a `GoogleService-Info.plist` checked in that points at the Firebase project we used during the hackathon. Anyone running the app right now writes fall events into that same project, which is fine for a demo but obviously not what you want in production.

To point at your own Firestore:

1. Create a Firebase project at <https://console.firebase.google.com>.
2. Add an iOS app to it. Use whatever bundle ID you settled on above.
3. Download the `GoogleService-Info.plist` Firebase generates for you. Drop it into `ElderlyPrincetonHacks/` (replace the existing one).
4. In the Firebase console, go to **Authentication → Sign-in method** and **enable Anonymous**. The whole point of the no-SDK approach is that we anonymously sign each install in and use that token to write — no auth means no writes.
5. In **Firestore Database**, create a database in production mode. Loosen the rules to whatever you're comfortable with for the demo. For a real deployment you'd lock writes to documents whose `userName` matches the anonymous user's claim — but at the hackathon level we kept rules permissive.

The watch needs no changes. It uploads via the iPhone, which uses whatever `GoogleService-Info.plist` is in the bundle.

---

## Building and running

The fastest path is the script:

```bash
./install-to-watch.sh
```

It auto-detects your connected iPhone and paired Apple Watch, builds both targets, signs them with whichever team Xcode has cached, and pushes the binaries directly via `xcrun devicectl` — bypassing the Xcode IDE entirely. Takes about 30 seconds on a warm build.

If you have multiple devices connected and the script picks the wrong one:

```bash
PHONE_DEVICE_ID=<udid> WATCH_DEVICE_ID=<udid> ./install-to-watch.sh
```

You can find UDIDs with `xcrun devicectl list devices`.

The traditional path also works: open `ElderlyPrincetonHacks.xcodeproj` in Xcode, select the **GuardianWatch Watch App** scheme, point at your watch, hit Run. Then switch to the **ElderlyPrincetonHacks** scheme and run that against the iPhone. Xcode will complain more than the script does.

### First launch on each device

The first time you launch a sideloaded app on iOS or watchOS, the system blocks it pending developer trust. On the iPhone:

> Settings → General → VPN & Device Management → tap your Apple ID → Trust

The watch usually inherits that trust automatically once it's set on the iPhone. If it doesn't, the equivalent screen on watchOS is under Settings → General → Device Management.

After that, launch the iPhone app first so the watch connectivity bridge has a session to talk to. Then go to the watch, find Guardian in the app grid (you may need to pan around — sideloaded apps don't always land in the spot you expect), tap to launch, walk through the one-time onboarding (name, age, emergency contact, gait calibration walk).

---

## Testing it for real

A real fall test is uncomfortable, both because we're going to throw the watch around and because we want it to actually trigger so we know the thresholds are right. Here's the safe version:

1. Lay a pillow or cushion on the ground.
2. With monitoring enabled on the watch, hold the watch in your hand at standing height.
3. Drop it onto the cushion. Don't toss — just open your hand. We want a free-fall, not a throw.
4. Within about a second of impact, the watch should vibrate, the speaker should say "I detected a possible fall," and the alert UI should fill the screen.
5. Tap *I'm OK*. The event is recorded with outcome `cancelledByUser` and uploaded.
6. Open Firebase Console → Firestore → `fall_events`. The new document should appear within a few seconds (the watch hands off to the iPhone, which posts to Firestore over Wi-Fi/cellular).

If you want to test the dispatch path too, set the emergency contact to your own phone number during onboarding and let the countdown run out. You'll get a real call from your watch.

A note on thresholds: real falls in elderly users tend to look softer than the dramatic stunt-falls used in research datasets. We tuned conservatively to avoid false positives, which means very gentle "slumping" falls may not trigger. The thresholds are all in `GuardianWatchApp/Utilities/Constants.swift` under `Sensitivity` — lower the acceleration threshold to be more aggressive.

---

## Known limitations

We're being honest here.

- **The watch can write to Firestore only when the iPhone is reachable from the watch's connectivity stack.** "Reachable" means the iPhone is awake or has been awake recently and the two are within Bluetooth or Wi-Fi range of each other. In practice this is "almost always" but not "always." Events queue while disconnected and deliver later — they're not lost, but they're not real-time either. If your use case requires real-time independent watch-to-cloud, you'd want a cellular Apple Watch with its own data plan and the Firebase REST client moved into the watch target. We left it as is because the iPhone is more reliable, more efficient on battery, and almost always nearby.
- **No user identity yet.** Every install signs in anonymously. There is no "Pulkit's events" vs "Aryan's events" partitioning beyond the document ID. Production would need real auth — the structure is there, just bring up Sign-in with Apple and replace the anonymous bootstrap.
- **The K2 Think and ElevenLabs API keys are committed in `Constants.swift`.** That was fine for the hackathon — we wanted anyone running the demo to get the LLM and TTS features without provisioning their own keys — but you'd never do this in a real product. Rotate them and pull from a Settings screen (the UI is already in `SettingsView.swift`) before shipping anything.
- **The Live Activity extension uses a hardcoded development team ID** in `project.pbxproj` (Aryan's). If you build the extension yourself you'll need to either delete the target or change the team. Easier to just leave the extension out of your build — set `INFOPLIST_KEY_NSSupportsLiveActivities = NO` for the iOS target and remove it from the Embed Foundation Extensions phase.
- **HealthKit history reads aren't wired up.** We request the entitlement so HKWorkoutSession can run; we don't currently mine the wearer's existing health history for context. That's an obvious next step.

---

## Tech stack

**Languages:** Swift 5+, with the new Swift 6 concurrency features (`@MainActor`, `Task`, structured concurrency throughout).

**Frameworks:** SwiftUI for everything UI on both platforms. CoreMotion for the sensor pipeline. HealthKit for `HKWorkoutSession`-based background execution on watchOS. CoreLocation for incident geotagging. AVFoundation (`AVSpeechSynthesizer`, `AVAudioSession`) for the watch's voice prompts and the iPhone's ElevenLabs streaming. WatchConnectivity for the watch-to-phone bridge. WatchKit for the watchOS-only bits (`WKExtension`, haptics, system URLs). ActivityKit for iPhone Live Activities. UserNotifications for local notifications.

**External services:** Cloud Firestore via REST (no SDK). Firebase Authentication (anonymous, via REST). OpenAI-compatible K2 Think for the contextual emergency reasoning. ElevenLabs for streaming text-to-speech and transcription on iOS.

**No package dependencies.** No SPM, no CocoaPods, no Carthage. Every library is first-party Apple. This was deliberate — hackathon judges don't want to wait for `xcodebuild` to resolve a dependency graph, and it keeps the project trivially clonable.

---

## File map

```
ElderlyPrincetonHacks/             iOS companion app
├── App/                           AppDelegate, lifecycle hooks
├── DesignSystem/                  Colors, typography, neumorphic components
├── LiveActivity/                  ActivityKit attribute definitions
├── Models/                        AppState, FallEvent, UserProfile, GaitBaseline
├── Services/                      The brain
│   ├── AIAgentService.swift           OpenAI/K2 Think wrapper
│   ├── AudioClassificationService.swift   On-device sound scene classifier
│   ├── BackgroundMonitorService.swift     iOS background task bridge
│   ├── CrisisReasoningService.swift       LLM-driven situation assessor
│   ├── ElevenLabsTranscriptionService.swift  Streaming STT
│   ├── EmergencyDispatchService.swift     Tel:// dialer + notification
│   ├── FallDetectionEngine.swift          Same logic as watch, phone-source
│   ├── FallFirestoreService.swift         Firebase REST + anon auth
│   ├── GaitAnalysisService.swift          Cadence/variance scoring
│   ├── K2ThinkClient.swift                OpenAI-compatible chat client
│   ├── LiveActivityManager.swift          ActivityKit lifecycle
│   ├── LocalNotificationService.swift     UNUserNotificationCenter wrapper
│   ├── LocationService.swift              CoreLocation
│   ├── MotionService.swift                CoreMotion sample loop
│   └── WatchConnectivityService.swift     ⬅ NEW: receives falls from watch
├── Utilities/                     Constants, extensions
├── Views/                         SwiftUI screens
│   ├── Caregiver/                     Family-member dashboards
│   ├── Components/                    Reusable UI
│   ├── FallAlert/                     Active alert + confirmation
│   ├── Main/                          Tab root, dashboard, history
│   ├── Onboarding/                    First-run flow
│   └── Settings/                      Profile, contacts, API keys
└── GoogleService-Info.plist       Firebase config (replace with yours)

GuardianWatchApp/                  Apple Watch app — fully independent
├── Assets.xcassets                Watch-specific icon set
├── GuardianWatchApp.entitlements  HealthKit only
├── GuardianWatchApp.swift         @main, scene phase handling
├── Models/                        Mirrored data shapes (wire-compatible w/ iOS)
├── Services/
│   ├── AIAgentService.swift           OpenAI + AVSpeechSynthesizer
│   ├── BackgroundRefreshService.swift WKApplication.scheduleBackgroundRefresh
│   ├── EmergencyDispatchService.swift WKExtension.openSystemURL
│   ├── FallDetectionEngine.swift      The pipeline described above
│   ├── GaitAnalysisService.swift      Live gait scoring vs baseline
│   ├── HapticsService.swift           WKInterfaceDevice haptics
│   ├── LocationService.swift          CoreLocation on the watch
│   ├── MotionService.swift            CMMotionManager driver
│   ├── WatchConnectivityService.swift ⬅ NEW: sends falls to iPhone
│   └── WorkoutSessionManager.swift    HKWorkoutSession lifecycle
├── Utilities/                     Constants (sensitivity thresholds!), Theme
└── Views/                         RootTabView and 6 tab screens

GuardianLiveActivityExtension/     Optional iOS widget extension

install-to-watch.sh                One-shot deploy script
```

---

## Credits

Built at **Princeton Hacks 2026** by Aryan and Pulkit. The original iOS app is Aryan's; Pulkit ported it to watchOS, redesigned the UX for the small screen, and built the watch-to-cloud bridge.

The hardware itself does the hard part. We just listened to it carefully.

---

## License

No license file shipped. Treat this as personal/educational code for now. If you want to use it for anything serious, talk to us first.
