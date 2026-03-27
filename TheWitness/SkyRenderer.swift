import Foundation
import CoreGraphics

/// Day/night sky color computation — exact port of skyC function
struct SkyRenderer {
    /// Compute sky colors for a given day phase (0..1)
    static func skyColors(phase p: Double) -> SkyColors {
        let ph = p.truncatingRemainder(dividingBy: 1.0)
        var tr: Double, tg: Double, tb: Double
        var br: Double, bg: Double, bb: Double
        var am: Double

        if ph < 0.2 {
            let q = ph / 0.2
            tr = 8 + q * 8; tg = 8 + q * 12; tb = 22 + q * 18
            br = 10 + q * 15; bg = 10 + q * 18; bb = 28 + q * 22
            am = 0.06 + q * 0.06
        } else if ph < 0.3 {
            let q = (ph - 0.2) / 0.1
            tr = 16 + q * 35; tg = 20 + q * 30; tb = 40 + q * 50
            br = 25 + q * 150; bg = 28 + q * 90; bb = 50 + q * 55
            am = 0.12 + q * 0.4
        } else if ph < 0.55 {
            let q = (ph - 0.3) / 0.25
            tr = 51 + q * 15; tg = 50 + q * 55; tb = 90 + q * 70
            br = 175 - q * 20; bg = 118 + q * 40; bb = 105 - q * 25
            am = 0.52 + q * 0.4
        } else if ph < 0.75 {
            let q = (ph - 0.55) / 0.2
            tr = 66 - q * 12; tg = 105 + q * 5; tb = 160 - q * 15
            br = 155 - q * 10; bg = 158 - q * 30; bb = 80 + q * 25
            am = 0.92 - q * 0.15
        } else if ph < 0.85 {
            let q = (ph - 0.75) / 0.1
            tr = 54 - q * 30; tg = 110 - q * 65; tb = 145 - q * 95
            br = 145 + q * 60; bg = 128 - q * 70; bb = 105 - q * 50
            am = 0.77 - q * 0.42
        } else {
            let q = (ph - 0.85) / 0.15
            tr = 24 - q * 16; tg = 45 - q * 37; tb = 50 - q * 28
            br = 205 - q * 195; bg = 58 - q * 48; bb = 55 - q * 27
            am = 0.35 - q * 0.29
        }

        return SkyColors(
            topR: tr, topG: tg, topB: tb,
            botR: br, botG: bg, botB: bb,
            ambient: am
        )
    }

    /// Sun position for a given phase, screen dimensions
    static func sunPosition(phase: Double, width: Double, height: Double) -> CGPoint {
        let angle = phase * .pi * 2 - .pi / 2
        let x = width / 2 + cos(angle) * width * 0.4
        let y = height * 0.42 - sin(angle) * height * 0.4
        return CGPoint(x: x, y: y)
    }
}
