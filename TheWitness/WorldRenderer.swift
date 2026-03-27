import Foundation
import CoreGraphics

/// Renders ground terrain, water, zone life overlays, grasses, background mountains
struct WorldRenderer {

    // MARK: - Background Mountains (3 layers)
    static func drawBackgroundMountains(
        terrain: TerrainGenerator,
        camX: Double, camY: Double,
        ambient am: Double, worldLife: Double,
        in ctx: CGContext, W: Double, H: Double
    ) {
        let ds = 1 - worldLife * 0.6
        let ni = max(0, 1 - am * 2.5)

        for l in 0..<3 {
            let parallax: [Double] = [0.1, 0.2, 0.35]
            let off = -camX * parallax[l]
            let yO = -camY * parallax[l] * 0.3

            let dcR: [Double] = [50 + am * 28, 38 + am * 32, 30 + am * 28]
            let dcG: [Double] = [58 + am * 32, 52 + am * 38, 50 + am * 48]
            let dcB: [Double] = [80 + am * 38, 60 + am * 32, 38 + am * 28]
            let nm: [Double] = [0.15, 0.12, 0.1]

            var mr = dcR[l] * (1 - ni) + dcR[l] * nm[l] * ni
            var mg = dcG[l] * (1 - ni) + dcG[l] * nm[l] * ni
            var mb = dcB[l] * (1 - ni) + dcB[l] * nm[l] * ni

            let gg = (mr + mg + mb) / 3
            mr = mr * (1 - ds * 0.4) + gg * ds * 0.4
            mg = mg * (1 - ds * 0.4) + gg * ds * 0.4
            mb = mb * (1 - ds * 0.4) + gg * ds * 0.4

            ctx.setFillColor(CGColor(red: mr / 255, green: mg / 255, blue: mb / 255, alpha: 1))
            ctx.beginPath()
            ctx.move(to: CGPoint(x: -5, y: H + 5))
            var x = -5.0
            while x <= W + 5 {
                let bh = terrain.backgroundHeight(worldX: x - off, layer: l) * H + yO
                ctx.addLine(to: CGPoint(x: x, y: bh))
                x += 3
            }
            ctx.addLine(to: CGPoint(x: W + 5, y: H + 5))
            ctx.closePath()
            ctx.fillPath()
        }
    }

    // MARK: - Main Ground Terrain (dead base color)
    static func drawGround(
        terrain: TerrainGenerator,
        camX: Double, camY: Double,
        ambient am: Double,
        in ctx: CGContext, W: Double, H: Double
    ) {
        let ni = max(0, 1 - am * 2.5)
        let dR = 25 + am * 15
        let dG = 23 + am * 14
        let dB = 22 + am * 13

        let r = dR * (1 - ni) + dR * 0.07 * ni
        let g = dG * (1 - ni) + dG * 0.07 * ni
        let b = dB * (1 - ni) + dB * 0.07 * ni

        ctx.setFillColor(CGColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: -5, y: H + 5))
        var x = -5.0
        while x <= W + 5 {
            let th = terrain.terrainHeight(worldX: x + camX) * H - camY * 0.5
            ctx.addLine(to: CGPoint(x: x, y: th))
            x += 2
        }
        ctx.addLine(to: CGPoint(x: W + 5, y: H + 5))
        ctx.closePath()
        ctx.fillPath()
    }

    // MARK: - Zone Life Overlay
    static func drawZoneLife(
        terrain: TerrainGenerator,
        camX: Double, camY: Double,
        ambient am: Double,
        in ctx: CGContext, W: Double, H: Double
    ) {
        let zw = GameConstants.zoneWidth
        for z in 0..<GameConstants.zoneCount {
            let lf = terrain.zoneLevels[z]
            guard lf >= 0.01 else { continue }

            let z1 = Double(z) * zw - camX
            let z2 = Double(z + 1) * zw - camX
            guard z2 >= -10, z1 <= W + 10 else { continue }

            let left = max(-5, z1)
            let right = min(W + 5, z2)

            ctx.saveGState()
            ctx.beginPath()
            ctx.move(to: CGPoint(x: left, y: H + 5))
            var x = left
            while x <= right {
                let th = terrain.terrainHeight(worldX: x + camX) * H - camY * 0.5
                ctx.addLine(to: CGPoint(x: x, y: th))
                x += 2
            }
            ctx.addLine(to: CGPoint(x: right, y: H + 5))
            ctx.closePath()
            ctx.clip()

            let lr = 20 + am * 30 + lf * 5
            let lg = 22 + am * 25 + lf * 38
            let lb = 18 + am * 12 + lf * 8

            // Gradient fill
            let colors: [CGColor] = [
                CGColor(red: lr / 255, green: lg / 255, blue: lb / 255, alpha: lf),
                CGColor(red: lr * 0.8 / 255, green: lg * 0.75 / 255, blue: lb * 0.7 / 255, alpha: lf),
                CGColor(red: lr * 0.55 / 255, green: lg * 0.5 / 255, blue: lb * 0.45 / 255, alpha: lf),
            ]
            let locations: [CGFloat] = [0, 0.6, 1]
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: locations
            ) {
                ctx.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: H * 0.5),
                    end: CGPoint(x: 0, y: H),
                    options: []
                )
            }
            ctx.restoreGState()
        }
    }

    // MARK: - Water
    static func drawWater(
        terrain: TerrainGenerator,
        skyColors s: SkyColors,
        camX: Double, camY: Double,
        time: Double,
        in ctx: CGContext, W: Double, H: Double
    ) {
        var x = 0.0
        while x < W {
            let twx = x + camX
            let wlv = terrain.waterAt(worldX: twx)
            guard wlv > 0 else { x += 2; continue }
            let th = terrain.terrainHeight(worldX: twx)
            guard th <= wlv + 0.003 else { x += 2; continue }

            let sy = wlv * H - camY * 0.5
            let dep = (wlv - th) * H
            let rip = sin(twx * 0.03 + time * 1.5) * 1.2 + sin(twx * 0.07 + time * 2.1) * 0.5
            let ll = terrain.lifeAt(worldX: twx)

            let wr = s.topR * 0.2 + 15 + ll * 5
            let wg = s.topG * 0.2 + 20 + ll * 18
            let wb = s.topB * 0.3 + 25 + ll * 22
            let wa = 0.2 + min(dep / 30, 0.35)

            ctx.setFillColor(CGColor(red: wr / 255, green: wg / 255, blue: wb / 255, alpha: wa))
            ctx.fill(CGRect(x: x, y: sy + rip, width: 3, height: dep))
            x += 2
        }
    }

    // MARK: - Grasses
    static func drawGrasses(
        terrain: TerrainGenerator,
        camX: Double, camY: Double,
        ambient am: Double, windTime wt: Double,
        in ctx: CGContext, W: Double, H: Double
    ) {
        var x = 0.0
        while x < W {
            let gwx = x + camX
            let ll = terrain.lifeAt(worldX: gwx)
            guard ll >= 0.1 else { x += 5 + Double(Int(x * 7) % 3); continue }

            let gth = terrain.terrainHeight(worldX: gwx)
            let gy = gth * H - camY * 0.5
            guard gy >= H * 0.35 && gy <= H + 5 else { x += 5 + Double(Int(x * 7) % 3); continue }

            let gh = (6 + terrain.noise.fbm(gwx * 0.01, 5, octaves: 2) * 18) * ll
            let wb = sin(wt + gwx * 0.014) * 4 * ll
            let ggg = 25 + am * 70 + ll * 40 + terrain.noise.fbm(gwx * 0.005, 9, octaves: 2) * 20

            ctx.setStrokeColor(CGColor(
                red: (15 + am * 15) / 255,
                green: ggg / 255,
                blue: (12 + am * 12) / 255,
                alpha: (0.15 + am * 0.25) * ll
            ))
            ctx.setLineWidth(0.6)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: x, y: gy))
            ctx.addQuadCurve(
                to: CGPoint(x: x + wb, y: gy - gh),
                control: CGPoint(x: x + wb * 0.4, y: gy - gh * 0.5)
            )
            ctx.strokePath()

            x += 5 + Double(Int(x * 7) % 3)
        }
    }
}
