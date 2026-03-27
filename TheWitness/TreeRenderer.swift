import Foundation
import CoreGraphics

/// Fractal tree rendering — port of dT/dBr functions
struct TreeRenderer {
    /// Draw a complete tree
    static func drawTree(
        _ tree: Tree,
        screenX sx: Double,
        ambient am: Double,
        windTime wt: Double,
        lifeLevel lf: Double,
        time: Double,
        in ctx: CGContext,
        screenH: Double
    ) {
        let m = min(1.0, tree.maturity)
        guard m >= 0.02 else { return }

        let dna = tree.dna
        let h = dna.height * m
        let isDead = tree.isDead
        let wind = sin(wt + tree.worldX * 0.01) * (isDead ? 0.5 : 3.0) * m

        // Trunk
        let bk = isDead ? 15 + am * 12 : 22 + am * 30
        let trunkR = bk
        let trunkG = bk * (isDead ? 0.9 : 0.8)
        let trunkB = bk * (isDead ? 0.95 : 0.6)
        let trunkAlpha = (isDead ? 0.4 : 0.7) * m

        ctx.setStrokeColor(CGColor(
            red: trunkR / 255, green: trunkG / 255, blue: trunkB / 255, alpha: trunkAlpha
        ))
        ctx.setLineWidth(dna.trunkWidth * m + 0.5)

        let baseY = tree.baseY
        let topX = sx + wind * 0.5
        let topY = baseY - h

        ctx.beginPath()
        ctx.move(to: CGPoint(x: sx, y: baseY))
        ctx.addQuadCurve(
            to: CGPoint(x: topX, y: topY),
            control: CGPoint(x: sx + wind * 0.3, y: baseY - h * 0.5)
        )
        ctx.strokePath()

        // Main branches
        drawBranch(
            bx: topX, by: topY,
            angle: -.pi / 2 - 0.2, length: h * 0.42,
            depth: dna.depth, thickness: dna.trunkWidth * 0.65,
            dna: dna, maturity: m, ambient: am, windTime: wt,
            isDead: isDead, lifeLevel: lf, tree: tree,
            time: time, ctx: ctx
        )
        drawBranch(
            bx: topX, by: topY,
            angle: -.pi / 2 + 0.2, length: h * 0.42,
            depth: dna.depth, thickness: dna.trunkWidth * 0.65,
            dna: dna, maturity: m, ambient: am, windTime: wt,
            isDead: isDead, lifeLevel: lf, tree: tree,
            time: time, ctx: ctx
        )
        if m > 0.5 {
            drawBranch(
                bx: topX, by: topY - h * 0.08,
                angle: -.pi / 2 + 0.45, length: h * 0.28,
                depth: dna.depth - 1, thickness: dna.trunkWidth * 0.45,
                dna: dna, maturity: m, ambient: am, windTime: wt,
                isDead: isDead, lifeLevel: lf, tree: tree,
                time: time, ctx: ctx
            )
        }
    }

    /// Recursive branch drawing
    private static func drawBranch(
        bx: Double, by: Double,
        angle ang: Double, length len: Double,
        depth dep: Int, thickness th: Double,
        dna: TreeDNA, maturity mt: Double,
        ambient am: Double, windTime wt: Double,
        isDead: Bool, lifeLevel lf: Double,
        tree: Tree, time: Double,
        ctx: CGContext
    ) {
        guard dep > 0, len >= 1.5 else { return }

        let wb = sin(wt * 1.4 + bx * 0.018 + Double(dep)) * 0.06 * mt
        let ex = bx + cos(ang + wb + dna.lean) * len
        let ey = by + sin(ang + wb + dna.lean) * len

        // Dead trees skip some terminal branches
        if isDead && dep <= 2 && sin(bx * 3 + Double(dep) * 7) > 0.3 {
            return
        }

        let bk = isDead ? 15 + am * 12 : 28 + am * 28
        let brR = bk
        let brG = bk * (isDead ? 0.9 : 0.75)
        let brB = bk * (isDead ? 0.95 : 0.55)
        let brAlpha = 0.3 + Double(dep) * 0.12

        ctx.setStrokeColor(CGColor(
            red: brR / 255, green: brG / 255, blue: brB / 255, alpha: brAlpha
        ))
        ctx.setLineWidth(th * mt)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: bx, y: by))
        ctx.addLine(to: CGPoint(x: ex, y: ey))
        ctx.strokePath()

        // Recurse with random spread
        let sp = 0.8 + Double.random(in: 0..<0.4)
        drawBranch(
            bx: ex, by: ey,
            angle: ang - dna.branchAngle * sp,
            length: len * dna.branchRatio,
            depth: dep - 1, thickness: th * 0.6,
            dna: dna, maturity: mt, ambient: am, windTime: wt,
            isDead: isDead, lifeLevel: lf, tree: tree,
            time: time, ctx: ctx
        )
        drawBranch(
            bx: ex, by: ey,
            angle: ang + dna.branchAngle * sp,
            length: len * dna.branchRatio * 1.02,
            depth: dep - 1, thickness: th * 0.6,
            dna: dna, maturity: mt, ambient: am, windTime: wt,
            isDead: isDead, lifeLevel: lf, tree: tree,
            time: time, ctx: ctx
        )

        // Leaves on living trees at terminal branches
        if !isDead && dep <= 2 && mt > 0.3 {
            let lg = 20 + lf * 85 + am * 60 + dna.leafHue
            let lr = 8 + lf * 10 + am * 25 + dna.leafHue * 0.3
            let la = (0.15 + am * 0.35) * min(1, (mt - 0.3) / 0.3) * max(0.2, lf)

            let rr = (2 + Double.random(in: 0..<4)) * min(1, (mt - 0.2) / 0.4)

            ctx.setFillColor(CGColor(
                red: lr / 255, green: max(0, lg) / 255, blue: (lr * 0.4) / 255, alpha: la
            ))
            ctx.fillEllipse(in: CGRect(x: ex - rr, y: ey - rr, width: rr * 2, height: rr * 2))

            // Fruit
            if tree.hasFruit && dep == 1 && Double.random(in: 0..<1) > 0.65 {
                ctx.setFillColor(CGColor(red: 190.0/255, green: 70.0/255, blue: 70.0/255, alpha: la * 1.1))
                ctx.fillEllipse(in: CGRect(x: ex + 1.5 - 2.5, y: ey + 2 - 2.5, width: 5, height: 5))
            }
        }
    }
}
