import Foundation
import CoreGraphics

/// Central game state — owns all mutable game data and runs the simulation tick.
final class GameEngine: ObservableObject {
    private static let saveKey = "thewitness.world"

    // MARK: - Published state (drives SwiftUI redraws via TimelineView)
    let terrain: TerrainGenerator
    let player: PlayerState

    var trees: [Tree] = []
    var effects: [VisualEffect] = []
    var mycelium: [MyceliumLink] = []
    var birds: [Bird] = []
    var particles: [Particle] = []

    var seeds: Int = GameConstants.initialSeeds
    var planted: Int = 0
    var worldLife: Double = 0
    var ashCollected: Int = 0

    // Time
    var time: Double = 0
    var dayTime: Double = GameConstants.initialDayTime

    // Camera
    var camX: Double = 0
    var camY: Double = 0

    // Touch / input
    var touchInput = TouchInput()

    // MARK: - Init
    init() {
        let noise = PerlinNoise(seed: 0)
        self.terrain = TerrainGenerator(noise: noise)
        self.player = PlayerState()
        generateInitialTrees()
        generateParticles()
        restore()
    }

    // MARK: - Initial world population
    private func generateInitialTrees() {
        for _ in 0..<45 {
            let wx = Double.random(in: 0..<GameConstants.worldWidth)
            let h = terrain.terrainHeight(worldX: wx)
            guard h < 0.74 else { continue }
            let dna = TreeDNA(
                branchAngle: 0.3 + Double.random(in: 0..<0.2),
                branchRatio: 0.6 + Double.random(in: 0..<0.1),
                depth: 3 + Int.random(in: 0..<2),
                lean: (Double.random(in: 0..<1) - 0.5) * 0.2,
                leafHue: 0,
                trunkWidth: 1.5 + Double.random(in: 0..<2),
                height: 30 + Double.random(in: 0..<45)
            )
            trees.append(Tree(
                worldX: wx, baseY: 0, isDead: true, dna: dna,
                maturity: 0.4 + Double.random(in: 0..<0.5),
                isGrowing: false, growRate: 0, hasFruit: false, touchCount: 0
            ))
        }
    }

    private func generateParticles() {
        for _ in 0..<70 {
            particles.append(Particle(
                x: Double.random(in: 0..<GameConstants.worldWidth),
                y: Double.random(in: 0..<500),
                vx: (Double.random(in: 0..<1) - 0.5) * 0.3,
                vy: Double.random(in: 0..<1) > 0.5
                    ? -0.05 - 0.1 * Double.random(in: 0..<1)
                    : 0.02 + 0.05 * Double.random(in: 0..<1),
                size: 0.5 + Double.random(in: 0..<1.5),
                type: Double.random(in: 0..<1) > 0.5 ? .ash : .leaf,
                phase: Double.random(in: 0..<Double.pi * 2),
                speed: 1 + Double.random(in: 0..<2)
            ))
        }
    }

    // MARK: - Main tick
    func update(screenW W: Double, screenH H: Double) {
        let dt = GameConstants.dt
        time += dt
        dayTime += dt

        // Player physics
        player.update(terrain: terrain, camX: camX, screenH: H)
        player.updateTransformation(worldLife: worldLife)

        // Camera follow
        let wx = player.x + camX
        camX += (wx - W * 0.4 - camX) * 0.04
        let groundY = terrain.terrainHeight(worldX: wx) * H
        camY += ((groundY - H * 0.65) * 0.5 - camY) * 0.03
        camX = max(0, min(GameConstants.worldWidth - W, camX))

        // Hold timer
        if touchInput.isHolding {
            touchInput.holdTime += dt
        }
        if touchInput.justReleased {
            if touchInput.holdTime < 0.25 {
                interact(screenH: H)
            } else if touchInput.holdTime > 0.5 && seeds > 0 {
                plant(screenH: H)
            }
            touchInput.holdTime = 0
            touchInput.justReleased = false
        }

        // Grow trees
        for i in trees.indices {
            if trees[i].isGrowing {
                trees[i].maturity += trees[i].growRate * dt
                if trees[i].maturity >= 1 {
                    trees[i].isGrowing = false
                    trees[i].maturity = 1
                }
            }
            trees[i].baseY = terrain.terrainHeight(worldX: trees[i].worldX) * H
        }

        // World life
        worldLife = terrain.computeWorldLife()

        // Update effects
        for i in effects.indices {
            effects[i].time += dt
        }
        effects.removeAll { $0.time > $0.duration }

        // Mycelium decay
        for i in mycelium.indices {
            mycelium[i].alpha -= mycelium[i].decayRate
        }
        mycelium.removeAll { $0.alpha <= 0 }

        // Birds — spawn periodically
        if Int(time) % 8 == 0 && time - floor(time) < dt {
            spawnBirds(screenH: H)
        }
        // Bird physics
        for i in birds.indices {
            birds[i].vx += (birds[i].homeX - birds[i].x + sin(time * 0.3 + birds[i].homeX) * 80) * 3e-4
                + (Double.random(in: 0..<1) - 0.5) * 0.08
            birds[i].vy += ((H * 0.25 + sin(time * 0.5 + birds[i].homeX) * H * 0.08) - birds[i].y) * 5e-4
                + (Double.random(in: 0..<1) - 0.5) * 0.04
            birds[i].vx *= 0.98
            birds[i].vy *= 0.98
            birds[i].x += birds[i].vx
            birds[i].y += birds[i].vy
            birds[i].wingPhase += birds[i].wingSpeed * dt
        }

        // Particles
        for i in particles.indices {
            particles[i].x += particles[i].vx + sin(time * 0.3 + particles[i].y * 0.01) * 0.15
            particles[i].y += particles[i].vy + sin(time + particles[i].phase) * 0.08
            if particles[i].y < -15 { particles[i].y = H * 0.6 }
            if particles[i].y > H * 0.65 { particles[i].y = -15 }
        }
    }

    // MARK: - Plant seed
    func plant(screenH H: Double) {
        seeds -= 1
        planted += 1
        let wx = player.x + camX

        let dna = TreeDNA(
            branchAngle: 0.33 + Double.random(in: 0..<0.28),
            branchRatio: 0.61 + Double.random(in: 0..<0.13),
            depth: 4 + Int.random(in: 0..<2),
            lean: (Double.random(in: 0..<1) - 0.5) * 0.12,
            leafHue: Double.random(in: -8..<35),
            trunkWidth: 1.8 + Double.random(in: 0..<2),
            height: 38 + Double.random(in: 0..<55)
        )

        var rate = 0.007 + Double.random(in: 0..<0.004)
        // Near water grows faster
        let wl = terrain.waterAt(worldX: wx)
        let th = terrain.terrainHeight(worldX: wx)
        if wl > 0 && abs(th - wl) < 0.025 {
            rate *= 2.5
        }

        let tree = Tree(
            worldX: wx, baseY: th * H, isDead: false, dna: dna,
            maturity: 0, isGrowing: true, growRate: rate, hasFruit: false, touchCount: 0
        )
        trees.append(tree)

        effects.append(VisualEffect(x: player.x, y: player.y, duration: 2.5, type: .plant))
        terrain.addLife(at: wx, amount: 0.08, radius: 200)

        // Seed replenishment schedule (mirrors the JS setTimeout logic)
        if planted == 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.seeds += 3 }
        }
        if planted == 10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in self?.seeds += 4 }
        }
        if planted == 16 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) { [weak self] in self?.seeds += 5 }
        }
    }

    // MARK: - Interact (tap)
    func interact(screenH H: Double) {
        let wx = player.x + camX

        // Water interaction
        let wl = terrain.waterAt(worldX: wx)
        if wl > 0 && abs(player.y / H - wl) < 0.06 {
            effects.append(VisualEffect(x: player.x, y: player.y, duration: 3, type: .water))
            for i in trees.indices {
                if abs(trees[i].worldX - wx) < 250 && trees[i].isGrowing {
                    trees[i].growRate *= 1.12
                }
            }
            terrain.addLife(at: wx, amount: 0.04, radius: 250)
            return
        }

        // Dead tree interaction
        if let idx = trees.firstIndex(where: { abs($0.worldX - wx) < 35 && $0.isDead && $0.maturity > 0.3 }) {
            let tr = trees[idx]
            effects.append(VisualEffect(
                x: player.x,
                y: tr.baseY - tr.dna.height * tr.maturity * 0.4,
                duration: 2.5, type: .ash
            ))
            ashCollected += 1
            let nl = terrain.lifeAt(worldX: tr.worldX)
            if nl > 0.3 {
                terrain.addLife(at: tr.worldX, amount: 0.06, radius: 180)
                trees[idx].maturity -= 0.05
                if trees[idx].maturity <= 0.05 { seeds += 2 }
            }
            return
        }

        // Living tree interaction
        if let idx = trees.firstIndex(where: { abs($0.worldX - wx) < 35 && !$0.isDead && $0.maturity > 0.6 }) {
            let tr = trees[idx]
            effects.append(VisualEffect(
                x: player.x,
                y: tr.baseY - tr.dna.height * tr.maturity * 0.4,
                duration: 2, type: .touch
            ))
            trees[idx].touchCount += 1
            terrain.addLife(at: tr.worldX, amount: 0.03, radius: 150)

            if tr.maturity > 0.8 && !tr.hasFruit {
                trees[idx].hasFruit = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                    guard let self else { return }
                    self.seeds += 2
                    if let j = self.trees.firstIndex(where: { $0.id == tr.id }) {
                        self.trees[j].hasFruit = false
                    }
                }
            }
            if trees[idx].touchCount >= 2 {
                revealMycelium(wx: wx)
            }
            return
        }

        // Ground interaction
        effects.append(VisualEffect(x: player.x, y: player.y, duration: 2, type: .ground))
        terrain.addLife(at: wx, amount: 0.02, radius: 120)
    }

    // MARK: - Mycelium network reveal
    private func revealMycelium(wx: Double) {
        let nearby = trees.filter { abs($0.worldX - wx) < 500 && !$0.isDead && $0.maturity > 0.3 }
        for i in 0..<nearby.count {
            for j in (i + 1)..<nearby.count {
                guard abs(nearby[i].worldX - nearby[j].worldX) < 350 else { continue }
                let exists = mycelium.contains {
                    $0.aX == nearby[i].worldX && $0.bX == nearby[j].worldX
                }
                if !exists {
                    mycelium.append(MyceliumLink(
                        aX: nearby[i].worldX, aY: nearby[i].baseY,
                        bX: nearby[j].worldX, bY: nearby[j].baseY
                    ))
                }
            }
        }
    }

    // MARK: - Bird spawning
    private func spawnBirds(screenH H: Double) {
        let step = 250.0
        var wx = 0.0
        while wx < GameConstants.worldWidth {
            let count = trees.filter { abs($0.worldX - wx) < 180 && !$0.isDead && $0.maturity > 0.5 }.count
            if count >= 3 {
                let nearby = birds.filter { abs($0.homeX - wx) < 250 }.count
                if nearby < 2 {
                    birds.append(Bird(
                        x: wx,
                        y: H * 0.25 + Double.random(in: 0..<H * 0.12),
                        homeX: wx,
                        vx: (Double.random(in: 0..<1) - 0.5) * 2,
                        vy: 0,
                        wingPhase: Double.random(in: 0..<Double.pi * 2),
                        wingSpeed: 7 + Double.random(in: 0..<5),
                        size: 3 + Double.random(in: 0..<2)
                    ))
                }
            }
            wx += step
        }
    }

    func save() {
        let snapshot = WitnessSnapshot(
            zoneLevels: terrain.zoneLevels,
            player: PlayerSnapshot(
                x: player.x,
                y: player.y,
                vx: player.vx,
                vy: player.vy,
                isGrounded: player.isGrounded,
                facingRight: player.facingRight,
                alpha: player.alpha,
                leafCount: player.leafCount,
                windInfluence: player.windInfluence
            ),
            trees: trees,
            effects: effects,
            mycelium: mycelium,
            birds: birds,
            particles: particles,
            seeds: seeds,
            planted: planted,
            worldLife: worldLife,
            ashCollected: ashCollected,
            time: time,
            dayTime: dayTime,
            camX: camX,
            camY: camY
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.saveKey)
    }

    func restore() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.saveKey),
            let snapshot = try? JSONDecoder().decode(WitnessSnapshot.self, from: data)
        else { return }

        terrain.apply(zoneLevels: snapshot.zoneLevels)
        player.x = snapshot.player.x
        player.y = snapshot.player.y
        player.vx = snapshot.player.vx
        player.vy = snapshot.player.vy
        player.isGrounded = snapshot.player.isGrounded
        player.facingRight = snapshot.player.facingRight
        player.alpha = snapshot.player.alpha
        player.leafCount = snapshot.player.leafCount
        player.windInfluence = snapshot.player.windInfluence
        trees = snapshot.trees
        effects = snapshot.effects
        mycelium = snapshot.mycelium
        birds = snapshot.birds
        particles = snapshot.particles
        seeds = snapshot.seeds
        planted = snapshot.planted
        worldLife = snapshot.worldLife
        ashCollected = snapshot.ashCollected
        time = snapshot.time
        dayTime = snapshot.dayTime
        camX = snapshot.camX
        camY = snapshot.camY
    }

    func clearSave() {
        UserDefaults.standard.removeObject(forKey: Self.saveKey)
    }
}

private struct WitnessSnapshot: Codable {
    let zoneLevels: [Double]
    let player: PlayerSnapshot
    let trees: [Tree]
    let effects: [VisualEffect]
    let mycelium: [MyceliumLink]
    let birds: [Bird]
    let particles: [Particle]
    let seeds: Int
    let planted: Int
    let worldLife: Double
    let ashCollected: Int
    let time: Double
    let dayTime: Double
    let camX: Double
    let camY: Double
}
