import Foundation
import CoreGraphics

// MARK: - Constants (matching the HTML source)
enum GameConstants {
    static let worldWidth: Double = 5000
    static let zoneCount: Int = 50
    static let zoneWidth: Double = worldWidth / Double(zoneCount)
    static let dayLength: Double = 200
    static let dt: Double = 1.0 / 60.0
    static let gravity: Double = 0.38
    static let jumpVelocity: Double = -7.2
    static let moveAccel: Double = 0.55
    static let friction: Double = 0.88
    static let initialSeeds: Int = 3
    static let initialDayTime: Double = 42
}

// MARK: - Tree DNA (branching parameters)
struct TreeDNA: Codable {
    var branchAngle: Double   // a: .3-.5 (dead) or .33-.61 (alive)
    var branchRatio: Double   // r: .6-.7 (dead) or .61-.74 (alive)
    var depth: Int            // d: 3-4 (dead) or 4-5 (alive)
    var lean: Double          // l: random lean
    var leafHue: Double       // lh: color variation
    var trunkWidth: Double    // tw: 1.5-3.5
    var height: Double        // h: 30-75 base height
}

// MARK: - Tree
struct Tree: Identifiable, Codable {
    let id = UUID()
    var worldX: Double
    var baseY: Double         // computed from terrain height
    var isDead: Bool
    var dna: TreeDNA
    var maturity: Double      // 0..1, how grown
    var isGrowing: Bool
    var growRate: Double       // rt
    var hasFruit: Bool
    var touchCount: Int
}

// MARK: - Visual Effect
struct VisualEffect: Identifiable, Codable {
    let id = UUID()
    var x: Double
    var y: Double
    var time: Double = 0
    var duration: Double
    var type: EffectType

    enum EffectType: Codable {
        case plant, water, touch, ash, ground
    }
}

// MARK: - Mycelium Connection
struct MyceliumLink: Identifiable, Codable {
    let id = UUID()
    var aX: Double
    var aY: Double
    var bX: Double
    var bY: Double
    var alpha: Double = 0.7
    var decayRate: Double = 0.001
}

// MARK: - Bird
struct Bird: Identifiable, Codable {
    let id = UUID()
    var x: Double
    var y: Double
    var homeX: Double
    var vx: Double
    var vy: Double
    var wingPhase: Double
    var wingSpeed: Double
    var size: Double
}

// MARK: - Particle (ash or pollen)
struct Particle: Identifiable, Codable {
    let id = UUID()
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var size: Double
    var type: ParticleType
    var phase: Double
    var speed: Double

    enum ParticleType: Codable {
        case ash, leaf
    }
}

// MARK: - Sky Color Result
struct SkyColors {
    var topR: Double, topG: Double, topB: Double
    var botR: Double, botG: Double, botB: Double
    var ambient: Double
}

// MARK: - Touch Input State
struct TouchInput {
    var isHolding: Bool = false
    var holdTime: Double = 0
    var position: CGPoint = .zero
    var justReleased: Bool = false
}
