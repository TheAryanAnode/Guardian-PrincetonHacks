import Foundation

struct SensorSnapshot: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: Date

    let rotationX: Double
    let rotationY: Double
    let rotationZ: Double

    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double

    /// Gravity vector (device frame) from `CMDeviceMotion.gravity` — used for posture / tilt.
    let gravityX: Double
    let gravityY: Double
    let gravityZ: Double

    /// Radians; positive often indicates nose-down tilt when held in pocket — heuristic for “slouch”.
    let pitchRadians: Double

    var rotationMagnitude: Double {
        (rotationX * rotationX + rotationY * rotationY + rotationZ * rotationZ).squareRoot()
    }

    var accelerationMagnitude: Double {
        (accelerationX * accelerationX + accelerationY * accelerationY + accelerationZ * accelerationZ).squareRoot()
    }

    init(
        rotationX: Double = 0, rotationY: Double = 0, rotationZ: Double = 0,
        accelerationX: Double = 0, accelerationY: Double = 0, accelerationZ: Double = 0,
        gravityX: Double = 0, gravityY: Double = 0, gravityZ: Double = 0,
        pitchRadians: Double = 0,
        timestamp: Date = .now
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.rotationX = rotationX
        self.rotationY = rotationY
        self.rotationZ = rotationZ
        self.accelerationX = accelerationX
        self.accelerationY = accelerationY
        self.accelerationZ = accelerationZ
        self.gravityX = gravityX
        self.gravityY = gravityY
        self.gravityZ = gravityZ
        self.pitchRadians = pitchRadians
    }

    /// Degrees away from “upright” for UI (approximate).
    var forwardTiltDegrees: Double {
        abs(pitchRadians * 180.0 / .pi)
    }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, rotationX, rotationY, rotationZ
        case accelerationX, accelerationY, accelerationZ
        case gravityX, gravityY, gravityZ, pitchRadians
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        timestamp = try c.decodeIfPresent(Date.self, forKey: .timestamp) ?? .now
        rotationX = try c.decodeIfPresent(Double.self, forKey: .rotationX) ?? 0
        rotationY = try c.decodeIfPresent(Double.self, forKey: .rotationY) ?? 0
        rotationZ = try c.decodeIfPresent(Double.self, forKey: .rotationZ) ?? 0
        accelerationX = try c.decodeIfPresent(Double.self, forKey: .accelerationX) ?? 0
        accelerationY = try c.decodeIfPresent(Double.self, forKey: .accelerationY) ?? 0
        accelerationZ = try c.decodeIfPresent(Double.self, forKey: .accelerationZ) ?? 0
        gravityX = try c.decodeIfPresent(Double.self, forKey: .gravityX) ?? 0
        gravityY = try c.decodeIfPresent(Double.self, forKey: .gravityY) ?? 0
        gravityZ = try c.decodeIfPresent(Double.self, forKey: .gravityZ) ?? 0
        pitchRadians = try c.decodeIfPresent(Double.self, forKey: .pitchRadians) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(rotationX, forKey: .rotationX)
        try c.encode(rotationY, forKey: .rotationY)
        try c.encode(rotationZ, forKey: .rotationZ)
        try c.encode(accelerationX, forKey: .accelerationX)
        try c.encode(accelerationY, forKey: .accelerationY)
        try c.encode(accelerationZ, forKey: .accelerationZ)
        try c.encode(gravityX, forKey: .gravityX)
        try c.encode(gravityY, forKey: .gravityY)
        try c.encode(gravityZ, forKey: .gravityZ)
        try c.encode(pitchRadians, forKey: .pitchRadians)
    }
}
