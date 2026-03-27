import Foundation
import CoreGraphics

/// Player state and physics
final class PlayerState {
    var x: Double = 500        // screen-space x (relative to camera)
    var y: Double = 0          // screen-space y
    var vx: Double = 0
    var vy: Double = 0
    var isGrounded: Bool = false
    var facingRight: Bool = true
    var isMoving: Bool = false

    // Transformation state (player becomes more plant-like as world heals)
    var alpha: Double = 1.0
    var leafCount: Int = 0
    var windInfluence: Double = 0

    // Input state
    var moveLeft: Bool = false
    var moveRight: Bool = false
    var jumpPressed: Bool = false

    /// Update physics each frame
    func update(terrain: TerrainGenerator, camX: Double, screenH: Double) {
        isMoving = false

        if moveLeft {
            vx -= GameConstants.moveAccel
            facingRight = false
            isMoving = true
        }
        if moveRight {
            vx += GameConstants.moveAccel
            facingRight = true
            isMoving = true
        }
        if jumpPressed && isGrounded {
            vy = GameConstants.jumpVelocity
            isGrounded = false
        }

        // Friction & gravity
        vx *= GameConstants.friction
        vy += GameConstants.gravity

        x += vx
        y += vy

        // Ground collision
        let wx = x + camX
        let groundY = terrain.terrainHeight(worldX: wx) * screenH
        if y >= groundY {
            y = groundY
            vy = 0
            isGrounded = true
        }

        // Water drag
        let wl = terrain.waterAt(worldX: wx)
        if wl > 0 && y / screenH > wl - 0.01 {
            vx *= 0.92
            vy *= 0.85
        }

        // Walk spreads a tiny bit of life
        if isMoving {
            terrain.addLife(at: wx, amount: 3e-4, radius: 80)
        }
    }

    /// Update the player transformation based on world life
    func updateTransformation(worldLife: Double) {
        if worldLife > 0.55 {
            alpha = max(0.15, 1 - (worldLife - 0.55) / 0.45)
            leafCount = min(12, Int((worldLife - 0.55) / 0.04))
            windInfluence = min(1, (worldLife - 0.55) * 2)
        } else {
            alpha = 1.0
            leafCount = 0
            windInfluence = 0
        }
    }

    /// World X coordinate
    func worldX(camX: Double) -> Double {
        return x + camX
    }
}
