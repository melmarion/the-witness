import Foundation

/// Terrain generation — direct port of tH, bH, wAt, zone life functions
final class TerrainGenerator {
    let noise: PerlinNoise
    var zoneLevels: [Double]  // life level per zone, 0..1

    init(noise: PerlinNoise) {
        self.noise = noise
        self.zoneLevels = [Double](repeating: 0, count: GameConstants.zoneCount)
    }

    // MARK: - Terrain Height (normalized 0..1, multiply by screen H)
    /// Main ground surface height. Returns fraction of screen height (0=top, 1=bottom)
    func terrainHeight(worldX wx: Double) -> Double {
        var h = noise.fbm(wx * 7e-4, 3.7, octaves: 6) * 0.2
            + sin(wx * 9e-4) * 0.06
            + sin(wx * 0.003) * 0.03
        let valley = pow(max(0, 1 - abs((sin(wx * 5e-4 + 1) * 0.5 + 0.5) - 0.5) * 4), 2) * 0.05
        h -= valley
        return 0.63 + h
    }

    // MARK: - Background Hill Heights (3 layers)
    func backgroundHeight(worldX wx: Double, layer: Int) -> Double {
        let sc = [4e-4, 6e-4, 0.001][layer]
        let am = [0.16, 0.13, 0.1][layer]
        let bs = [0.33, 0.41, 0.50][layer]
        return bs + noise.fbm(wx * sc, Double(layer) * 7 + 1, octaves: 4) * am
            + sin(wx * sc * 2) * am * 0.4
    }

    // MARK: - Water Level
    /// Returns water surface height (fraction), or -1 if no water
    func waterAt(worldX wx: Double) -> Double {
        let threshold = 0.695
        let h = terrainHeight(worldX: wx)
        return h < threshold ? threshold : -1
    }

    // MARK: - Zone Life
    /// Get interpolated life level at world X
    func lifeAt(worldX wx: Double) -> Double {
        let z = max(0, min(GameConstants.zoneCount - 1,
                           Int(floor(wx / GameConstants.zoneWidth))))
        let f = (wx.truncatingRemainder(dividingBy: GameConstants.zoneWidth)) / GameConstants.zoneWidth
        let z2 = min(GameConstants.zoneCount - 1, z + 1)
        return zoneLevels[z] * (1 - f) + zoneLevels[z2] * f
    }

    /// Add life around a world X position
    func addLife(at wx: Double, amount: Double, radius: Double = 150) {
        for z in 0..<GameConstants.zoneCount {
            let zCenter = Double(z) * GameConstants.zoneWidth + GameConstants.zoneWidth / 2
            let d = abs(zCenter - wx)
            if d < radius {
                let f = 1 - d / radius
                zoneLevels[z] = min(1, zoneLevels[z] + amount * f * f)
            }
        }
    }

    /// Compute overall world life (average of all zones)
    func computeWorldLife() -> Double {
        var total = 0.0
        for z in 0..<GameConstants.zoneCount {
            total += zoneLevels[z]
        }
        return total / Double(GameConstants.zoneCount)
    }
}
