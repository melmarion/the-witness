import SwiftUI

/// TimelineView + Canvas that renders the full scene each frame.
struct WorldCanvasView: View {
    let engine: GameEngine

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let W = size.width
                let H = size.height

                // Tick the simulation
                engine.update(screenW: W, screenH: H)

                // Resolve rendering context to CGContext via image
                guard let cgCtx = CGContext(
                    data: nil,
                    width: Int(W),
                    height: Int(H),
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else { return }

                // Flip coordinate system (CG is bottom-up, we want top-down like Canvas2D)
                cgCtx.translateBy(x: 0, y: H)
                cgCtx.scaleBy(x: 1, y: -1)

                let t = engine.time
                let dayPhase = (engine.dayTime / GameConstants.dayLength).truncatingRemainder(dividingBy: 1)
                let sky = SkyRenderer.skyColors(phase: dayPhase)
                let am = sky.ambient
                let wt = t * 0.7
                let ds = 1 - engine.worldLife * 0.6
                let camX = engine.camX
                let camY = engine.camY

                // === SKY GRADIENT ===
                drawSky(sky: sky, ds: ds, in: cgCtx, W: W, H: H)

                // === ASH IN SKY ===
                if engine.worldLife < 0.5 {
                    drawAshSky(worldLife: engine.worldLife, time: t, in: cgCtx, W: W, H: H)
                }

                // === STARS ===
                if am < 0.2 {
                    drawStars(ambient: am, time: t, in: cgCtx, W: W, H: H)
                }

                // === SUN ===
                drawSun(phase: dayPhase, ambient: am, in: cgCtx, W: W, H: H)

                // === CLOUDS ===
                drawClouds(ambient: am, ds: ds, camX: camX, time: t, in: cgCtx, W: W, H: H)

                // === BACKGROUND MOUNTAINS ===
                WorldRenderer.drawBackgroundMountains(
                    terrain: engine.terrain,
                    camX: camX, camY: camY,
                    ambient: am, worldLife: engine.worldLife,
                    in: cgCtx, W: W, H: H
                )

                // === BIRDS ===
                for bird in engine.birds {
                    let bsx = bird.x - camX
                    guard bsx > -50, bsx < W + 50 else { continue }
                    EffectsRenderer.drawBird(bird, camX: camX, camY: camY, ambient: am, in: cgCtx)
                }

                // === PARTICLES ===
                drawParticles(engine.particles, terrain: engine.terrain, camX: camX, camY: camY, ambient: am, time: t, in: cgCtx, W: W, H: H)

                // === MAIN GROUND ===
                WorldRenderer.drawGround(
                    terrain: engine.terrain,
                    camX: camX, camY: camY, ambient: am,
                    in: cgCtx, W: W, H: H
                )

                // === ZONE LIFE OVERLAY ===
                WorldRenderer.drawZoneLife(
                    terrain: engine.terrain,
                    camX: camX, camY: camY, ambient: am,
                    in: cgCtx, W: W, H: H
                )

                // === WATER ===
                WorldRenderer.drawWater(
                    terrain: engine.terrain,
                    skyColors: sky,
                    camX: camX, camY: camY, time: t,
                    in: cgCtx, W: W, H: H
                )

                // === GRASSES ===
                WorldRenderer.drawGrasses(
                    terrain: engine.terrain,
                    camX: camX, camY: camY,
                    ambient: am, windTime: wt,
                    in: cgCtx, W: W, H: H
                )

                // === TREES ===
                let sorted = engine.trees.sorted { $0.baseY < $1.baseY }
                for tree in sorted {
                    let tsx = tree.worldX - camX
                    guard tsx > -120, tsx < W + 120 else { continue }
                    TreeRenderer.drawTree(
                        tree, screenX: tsx,
                        ambient: am, windTime: wt,
                        lifeLevel: engine.terrain.lifeAt(worldX: tree.worldX),
                        time: t, in: cgCtx, screenH: H
                    )
                }

                // === MYCELIUM ===
                for link in engine.mycelium {
                    EffectsRenderer.drawMycelium(link, camX: camX, time: t, in: cgCtx)
                }

                // === EFFECTS ===
                for effect in engine.effects {
                    EffectsRenderer.drawEffect(effect, camY: camY, time: t, in: cgCtx)
                }

                // === PLAYER ===
                drawPlayer(engine.player, camY: camY, ambient: am, time: t, worldLife: engine.worldLife, in: cgCtx, H: H)

                // === SEED HOLD GLOW ===
                if engine.touchInput.isHolding && engine.seeds > 0 {
                    drawSeedGlow(player: engine.player, camY: camY, holdTime: engine.touchInput.holdTime, in: cgCtx)
                }

                // === SEED DOTS (UI) ===
                drawSeedDots(count: engine.seeds, ambient: am, in: cgCtx, W: W)

                // === VIGNETTE ===
                drawVignette(ambient: am, in: cgCtx, W: W, H: H)

                // === WORLD BREATHE ===
                if engine.worldLife > 0.8 {
                    let br = sin(t * 0.5) * 0.01
                    cgCtx.setFillColor(CGColor(red: 100.0/255, green: 180.0/255, blue: 80.0/255, alpha: br * 0.5))
                    cgCtx.fill(CGRect(x: 0, y: 0, width: W, height: H))
                }

                // Composite the CGContext image into the SwiftUI Canvas
                if let image = cgCtx.makeImage() {
                    ctx.draw(Image(decorative: image, scale: 1), in: CGRect(origin: .zero, size: size))
                }
            }
        }
    }

    // MARK: - Sky
    private func drawSky(sky: SkyColors, ds: Double, in ctx: CGContext, W: Double, H: Double) {
        let gT = (sky.topR + sky.topG + sky.topB) / 3
        let gB = (sky.botR + sky.botG + sky.botB) / 3
        let smx = { (v: Double, g: Double) -> Double in v * (1 - ds * 0.5) + g * ds * 0.5 }

        let topColor = CGColor(
            red: smx(sky.topR, gT) / 255,
            green: smx(sky.topG, gT) / 255,
            blue: smx(sky.topB, gT) / 255, alpha: 1
        )
        let botColor = CGColor(
            red: smx(sky.botR, gB) / 255,
            green: smx(sky.botG, gB) / 255,
            blue: smx(sky.botB, gB) / 255, alpha: 1
        )

        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [topColor, botColor] as CFArray,
            locations: [0, 1]
        ) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: H),       // top in flipped coords
                end: CGPoint(x: 0, y: H * 0.45),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }
    }

    // MARK: - Ash in sky
    private func drawAshSky(worldLife: Double, time t: Double, in ctx: CGContext, W: Double, H: Double) {
        let aa = Int((1 - worldLife * 2) * 12)
        let ashAlpha = (1 - worldLife * 2) * 0.06
        ctx.setFillColor(CGColor(red: 120.0/255, green: 115.0/255, blue: 110.0/255, alpha: ashAlpha))
        for i in 0..<aa {
            let ax = (t * 10 + Double(i) * 173).truncatingRemainder(dividingBy: W)
            let ay = (t * 3 + Double(i) * 97 + sin(t + Double(i)) * 20).truncatingRemainder(dividingBy: H * 0.7)
            ctx.fill(CGRect(x: ax, y: ay, width: 1.5, height: 0.8))
        }
    }

    // MARK: - Stars
    private func drawStars(ambient am: Double, time t: Double, in ctx: CGContext, W: Double, H: Double) {
        let sa = (0.2 - am) / 0.2
        for i in 0..<100 {
            let fi = Double(i)
            let tw = sin(t * (1 + Double(i % 3) * 0.5) + fi) * 0.3 + 0.7
            let a = sa * tw * (0.2 + Double((i * 7) % 10) / 25)
            ctx.setFillColor(CGColor(red: 210.0/255, green: 215.0/255, blue: 230.0/255, alpha: a))
            let sx = (fi * 137.5 + fi * fi * 0.3).truncatingRemainder(dividingBy: W)
            let sy = (fi * 89.3 + fi * 0.7).truncatingRemainder(dividingBy: H * 0.42)
            let sr = Double(i % 5) * 0.2 + 0.3
            ctx.fillEllipse(in: CGRect(x: sx - sr, y: sy - sr, width: sr * 2, height: sr * 2))
        }
    }

    // MARK: - Sun
    private func drawSun(phase: Double, ambient am: Double, in ctx: CGContext, W: Double, H: Double) {
        let pos = SkyRenderer.sunPosition(phase: phase, width: W, height: H)
        guard pos.y < H * 0.55 else { return }

        // Glow
        let glowColors: [CGColor] = [
            CGColor(red: 1, green: (195 + am * 40) / 255, blue: (140 + am * 50) / 255, alpha: 0.7),
            CGColor(red: 1, green: (185 + am * 30) / 255, blue: (125 + am * 40) / 255, alpha: 0.15),
            CGColor(red: 1, green: 200.0/255, blue: 150.0/255, alpha: 0),
        ]
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors as CFArray, locations: [0, 0.15, 1]) {
            ctx.drawRadialGradient(g, startCenter: pos, startRadius: 0, endCenter: pos, endRadius: 60, options: [])
        }

        // Disc
        ctx.setFillColor(CGColor(red: 1, green: (215 + am * 30) / 255, blue: (175 + am * 30) / 255, alpha: 0.85))
        ctx.fillEllipse(in: CGRect(x: pos.x - 12, y: pos.y - 12, width: 24, height: 24))
    }

    // MARK: - Clouds
    private func drawClouds(ambient am: Double, ds: Double, camX: Double, time t: Double, in ctx: CGContext, W: Double, H: Double) {
        for i in 0..<5 {
            let fi = Double(i)
            let cx = (t * (2 + fi * 0.7) + fi * 300).truncatingRemainder(dividingBy: W + 400) - 200
            let cy = H * 0.04 + fi * H * 0.03
            let brt = min(255.0, 120 + am * 120)
            let ca = (0.08 + am * 0.15) * (1 - ds * 0.3)

            for j in 0..<4 {
                let fj = Double(j)
                let ppx = cx + (fj / 4 - 0.5) * 130 - camX * 0.1
                let ppy = cy + (sin(fj * 1.7) - 0.3) * 12
                let pr = 15 + fj * 7 + fi * 3

                let cloudColors: [CGColor] = [
                    CGColor(red: brt / 255, green: brt / 255, blue: (brt + 5) / 255, alpha: ca),
                    CGColor(red: brt / 255, green: brt / 255, blue: (brt + 5) / 255, alpha: 0),
                ]
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cloudColors as CFArray, locations: [0, 1]) {
                    ctx.drawRadialGradient(g, startCenter: CGPoint(x: ppx, y: ppy), startRadius: 0, endCenter: CGPoint(x: ppx, y: ppy), endRadius: pr, options: [])
                }
            }
        }
    }

    // MARK: - Particles
    private func drawParticles(
        _ particles: [Particle],
        terrain: TerrainGenerator,
        camX: Double, camY: Double,
        ambient am: Double, time t: Double,
        in ctx: CGContext, W: Double, H: Double
    ) {
        for p in particles {
            let sx = p.x - camX
            guard sx > -30, sx < W + 30 else { continue }
            let sy = p.y - camY * 0.25
            let ll = terrain.lifeAt(worldX: p.x)

            if ll < 0.3 {
                ctx.setFillColor(CGColor(red: 100.0/255, green: 95.0/255, blue: 90.0/255, alpha: (1 - ll * 3) * 0.05))
                ctx.fill(CGRect(x: sx, y: sy + abs(sin(t + p.phase)) * 2, width: 1.2, height: 0.6))
            } else if am > 0.3 {
                ctx.setFillColor(CGColor(red: 210.0/255, green: 200.0/255, blue: 170.0/255, alpha: 0.05 * am * ll))
                ctx.fillEllipse(in: CGRect(x: sx - p.size * 0.2, y: sy - p.size * 0.2, width: p.size * 0.8, height: p.size * 0.8))
            }

            // Firefly glow at night in alive zones
            if am < 0.32 && ll > 0.4 {
                let gl = sin(t * p.speed + p.phase)
                if gl > 0.2 {
                    let a = (gl - 0.2) * (1 - am * 3) * 0.4 * ll
                    let glowColors: [CGColor] = [
                        CGColor(red: 160.0/255, green: 210.0/255, blue: 80.0/255, alpha: a),
                        CGColor(red: 160.0/255, green: 210.0/255, blue: 80.0/255, alpha: 0),
                    ]
                    if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors as CFArray, locations: [0, 1]) {
                        ctx.drawRadialGradient(g, startCenter: CGPoint(x: sx, y: sy), startRadius: 0, endCenter: CGPoint(x: sx, y: sy), endRadius: 5, options: [])
                    }
                }
            }
        }
    }

    // MARK: - Player
    private func drawPlayer(
        _ player: PlayerState,
        camY: Double, ambient am: Double,
        time t: Double, worldLife: Double,
        in ctx: CGContext, H: Double
    ) {
        let moving = player.isMoving
        let bob = moving ? sin(t * 10) * 2 : sin(t * 2) * 0.5
        let ppx = player.x
        let ppy = player.y + bob - camY * 0.5
        let pb = 18 + am * 35

        ctx.setAlpha(CGFloat(player.alpha))

        // Shadow
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.07 + am * 0.07))
        ctx.saveGState()
        ctx.translateBy(x: ppx, y: ppy + 2)
        ctx.scaleBy(x: 5, y: 1.5)
        ctx.fillEllipse(in: CGRect(x: -1, y: -1, width: 2, height: 2))
        ctx.restoreGState()

        let bodyColor = CGColor(red: pb / 255, green: pb * 0.88 / 255, blue: pb * 0.82 / 255, alpha: 0.85)
        ctx.setFillColor(bodyColor)

        // Legs
        let ls = moving ? sin(t * 10) * 2.5 : 0
        ctx.fill(CGRect(x: ppx - 2.5 + ls, y: ppy - 7, width: 2, height: 7))
        ctx.fill(CGRect(x: ppx + 0.5 - ls, y: ppy - 7, width: 2, height: 7))

        // Body
        ctx.fill(CGRect(x: ppx - 3.5, y: ppy - 14, width: 7, height: 8))

        // Head
        ctx.fillEllipse(in: CGRect(x: ppx - 3.5, y: ppy - 20.5, width: 7, height: 7))

        // Leaves growing on player
        if player.leafCount > 0 {
            for i in 0..<player.leafCount {
                let la = (Double(i) / Double(player.leafCount)) * .pi * 2 + sin(t * 1.5 + Double(i)) * 0.3
                let ld = 5 + sin(t + Double(i) * 2) * 2
                ctx.setFillColor(CGColor(
                    red: (20 + am * 30) / 255,
                    green: (80 + am * 100) / 255,
                    blue: (15 + am * 20) / 255,
                    alpha: 0.3 + am * 0.3
                ))
                let lx = ppx + cos(la) * ld
                let ly = ppy - 12 + sin(la) * ld * 0.6
                let lr = 1.5 + sin(t + Double(i)) * 0.5
                ctx.fillEllipse(in: CGRect(x: lx - lr, y: ly - lr, width: lr * 2, height: lr * 2))
            }
        }

        ctx.setAlpha(1)
    }

    // MARK: - Seed hold glow
    private func drawSeedGlow(player: PlayerState, camY: Double, holdTime: Double, in ctx: CGContext) {
        let gl = min(holdTime / 0.6, 1.0)
        let ppx = player.x
        let ppy = player.y + (player.isMoving ? sin(engine.time * 10) * 2 : sin(engine.time * 2) * 0.5) - camY * 0.5

        let glowColors: [CGColor] = [
            CGColor(red: 130.0/255, green: 190.0/255, blue: 90.0/255, alpha: 0.22 * gl),
            CGColor(red: 130.0/255, green: 190.0/255, blue: 90.0/255, alpha: 0),
        ]
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors as CFArray, locations: [0, 1]) {
            let center = CGPoint(x: ppx, y: ppy - 10)
            ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: 14 * gl, options: [])
        }

        if gl > 0.3 {
            ctx.setFillColor(CGColor(red: 110.0/255, green: 170.0/255, blue: 70.0/255, alpha: gl * 0.65))
            let seedX = ppx + (player.facingRight ? 4 : -4)
            let sz = 1.8 * gl
            ctx.fillEllipse(in: CGRect(x: seedX - sz, y: ppy - 12 - sz, width: sz * 2, height: sz * 2))
        }
    }

    // MARK: - Seed UI dots
    private func drawSeedDots(count: Int, ambient am: Double, in ctx: CGContext, W: Double) {
        for i in 0..<count {
            ctx.setFillColor(CGColor(red: 160.0/255, green: 200.0/255, blue: 130.0/255, alpha: 0.2 + am * 0.15))
            ctx.fillEllipse(in: CGRect(x: W - 20 - Double(i) * 8 - 2, y: 20 - 2, width: 4, height: 4))
        }
    }

    // MARK: - Vignette
    private func drawVignette(ambient am: Double, in ctx: CGContext, W: Double, H: Double) {
        let center = CGPoint(x: W / 2, y: H / 2)
        let innerAlpha = 0.0
        let outerAlpha = 0.22 + (1 - am) * 0.28
        let colors: [CGColor] = [
            CGColor(red: 0, green: 0, blue: 0, alpha: innerAlpha),
            CGColor(red: 0, green: 0, blue: 0, alpha: outerAlpha),
        ]
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
            ctx.drawRadialGradient(g, startCenter: center, startRadius: H * 0.28, endCenter: center, endRadius: H * 0.85, options: [.drawsAfterEndLocation])
        }
    }
}
