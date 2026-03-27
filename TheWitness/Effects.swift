import Foundation
import CoreGraphics

/// Draw all visual effects (plant, water, touch, ash, ground ripples)
struct EffectsRenderer {

    static func drawEffect(_ e: VisualEffect, camY: Double, time: Double, in ctx: CGContext) {
        let p = e.time / e.duration
        guard p <= 1 else { return }
        let ey = e.y - camY * 0.5

        switch e.type {
        case .plant:
            let r = p * 35
            ctx.setStrokeColor(CGColor(red: 90.0/255, green: 170.0/255, blue: 70.0/255, alpha: (1 - p) * 0.35))
            ctx.setLineWidth(0.8)
            ctx.strokeEllipse(in: CGRect(x: e.x - r, y: ey - r, width: r * 2, height: r * 2))
            for i in 0..<5 {
                let an = (Double(i) / 5) * .pi * 2 + time * 2
                ctx.setFillColor(CGColor(red: 125.0/255, green: 200.0/255, blue: 90.0/255, alpha: (1 - p) * 0.25))
                let px = e.x + cos(an) * r * 0.5
                let py = ey - p * 18 + sin(an) * r * 0.25
                let sz = 1.2 * (1 - p)
                ctx.fillEllipse(in: CGRect(x: px - sz, y: py - sz, width: sz * 2, height: sz * 2))
            }

        case .water:
            for i in 0..<3 {
                let rp = (p + Double(i) * 0.15).truncatingRemainder(dividingBy: 1.0)
                ctx.setStrokeColor(CGColor(red: 125.0/255, green: 170.0/255, blue: 210.0/255, alpha: (1 - rp) * 0.18))
                ctx.setLineWidth(0.6)
                let rr = rp * 50
                ctx.strokeEllipse(in: CGRect(x: e.x - rr, y: ey - rr, width: rr * 2, height: rr * 2))
            }

        case .touch:
            for i in 0..<6 {
                let an = (Double(i) / 6) * .pi * 2
                ctx.setStrokeColor(CGColor(red: 190.0/255, green: 200.0/255, blue: 170.0/255, alpha: (1 - p) * 0.22))
                ctx.setLineWidth(0.4)
                ctx.beginPath()
                ctx.move(to: CGPoint(x: e.x, y: ey))
                ctx.addLine(to: CGPoint(x: e.x + cos(an) * p * 25, y: ey + sin(an) * p * 25))
                ctx.strokePath()
            }

        case .ash:
            for i in 0..<8 {
                let an = (Double(i) / 8) * .pi * 2 + time
                ctx.setFillColor(CGColor(red: 100.0/255, green: 95.0/255, blue: 88.0/255, alpha: (1 - p) * 0.18))
                let px = e.x + cos(an) * p * 30
                let py = ey + sin(an) * p * 20 - p * 15
                let sz = 1.5 * (1 - p)
                ctx.fillEllipse(in: CGRect(x: px - sz, y: py - sz, width: sz * 2, height: sz * 2))
            }

        case .ground:
            ctx.setStrokeColor(CGColor(red: 170.0/255, green: 150.0/255, blue: 110.0/255, alpha: (1 - p) * 0.2))
            ctx.setLineWidth(0.5)
            for i in 0..<4 {
                let an = (Double(i) / 4) * .pi + sin(Double(i) * 1.5) * 0.3
                ctx.beginPath()
                ctx.move(to: CGPoint(x: e.x, y: ey))
                var cx = e.x, cy = ey
                for s in 0..<3 {
                    let nx = cx + cos(an + sin(Double(s) * 2) * 0.4) * p * 35 * 0.3
                    let ny = cy + sin(an * 0.3 + Double(s)) * p * 35 * 0.12 + p * 35 * 0.16
                    ctx.addLine(to: CGPoint(x: nx, y: ny))
                    cx = nx; cy = ny
                }
                ctx.strokePath()
            }
        }
    }

    /// Draw mycelium network connections
    static func drawMycelium(_ link: MyceliumLink, camX: Double, time: Double, in ctx: CGContext) {
        let s1 = link.aX - camX
        let s2 = link.bX - camX

        ctx.setStrokeColor(CGColor(red: 170.0/255, green: 150.0/255, blue: 90.0/255, alpha: link.alpha * 0.22))
        ctx.setLineWidth(0.5)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: s1, y: link.aY + 4))
        let midY = max(link.aY, link.bY) + 16 + sin(time + link.aX) * 4
        ctx.addQuadCurve(
            to: CGPoint(x: s2, y: link.bY + 4),
            control: CGPoint(x: (s1 + s2) / 2, y: midY)
        )
        ctx.strokePath()

        // Traveling particle
        let pt = (time * 0.5 + link.aX * 0.01).truncatingRemainder(dividingBy: 1.0)
        ctx.setFillColor(CGColor(red: 190.0/255, green: 190.0/255, blue: 110.0/255, alpha: link.alpha * 0.35))
        let px = s1 + (s2 - s1) * pt
        let py = link.aY + (midY - link.aY) * 2 * pt * (1 - pt) + (link.bY - link.aY) * pt + 4
        ctx.fillEllipse(in: CGRect(x: px - 1.6, y: py - 1.6, width: 3.2, height: 3.2))
    }

    /// Draw a bird (simple wing-flap V shape)
    static func drawBird(_ bird: Bird, camX: Double, camY: Double, ambient am: Double, in ctx: CGContext) {
        let bsx = bird.x - camX
        let bsy = bird.y - camY * 0.35
        let wing = sin(bird.wingPhase) * 0.6
        let br = 28 + am * 40

        ctx.setStrokeColor(CGColor(
            red: br / 255, green: br / 255, blue: (br + 8) / 255, alpha: 0.4 + am * 0.3
        ))
        ctx.setLineWidth(1.1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: bsx - bird.size, y: bsy + wing * bird.size * 0.5))
        ctx.addQuadCurve(
            to: CGPoint(x: bsx + bird.size, y: bsy + wing * bird.size * 0.5),
            control: CGPoint(x: bsx, y: bsy - bird.size * 0.25)
        )
        ctx.strokePath()
    }
}
