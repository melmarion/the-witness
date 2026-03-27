import SwiftUI

/// Main game coordinator view with touch controls.
/// Drag left/right to move, tap to jump, long press to plant seed, tap objects to interact.
struct GameView: View {
    @StateObject private var engine = GameEngine()
    @StateObject private var audio = AudioEngine()

    // Gesture tracking
    @State private var dragStart: CGPoint? = nil
    @State private var dragCurrent: CGPoint? = nil
    @State private var longPressTimer: Timer? = nil
    @State private var touchStartTime: Date? = nil
    @State private var isTouching = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            WorldCanvasView(engine: engine)
                .ignoresSafeArea()
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleTouchChanged(value)
                        }
                        .onEnded { value in
                            handleTouchEnded(value)
                        }
                )
        }
        .onAppear {
            audio.startAmbience()
        }
        .onDisappear {
            audio.stop()
        }
    }

    // MARK: - Touch Handling

    private func handleTouchChanged(_ value: DragGesture.Value) {
        if dragStart == nil {
            // Touch began
            dragStart = value.startLocation
            touchStartTime = Date()
            isTouching = true
            engine.touchInput.isHolding = true
            engine.touchInput.holdTime = 0
            engine.touchInput.position = value.location
        }

        dragCurrent = value.location

        // Horizontal drag controls movement
        let deltaX = value.location.x - value.startLocation.x
        let threshold: CGFloat = 15

        if deltaX > threshold {
            engine.player.moveRight = true
            engine.player.moveLeft = false
        } else if deltaX < -threshold {
            engine.player.moveLeft = true
            engine.player.moveRight = false
        } else {
            engine.player.moveLeft = false
            engine.player.moveRight = false
        }

        // Vertical swipe up = jump
        let deltaY = value.location.y - value.startLocation.y
        if deltaY < -40 && engine.player.isGrounded {
            engine.player.jumpPressed = true
        }
    }

    private func handleTouchEnded(_ value: DragGesture.Value) {
        let totalDrag = hypot(
            value.location.x - value.startLocation.x,
            value.location.y - value.startLocation.y
        )
        let elapsed = -(touchStartTime?.timeIntervalSinceNow ?? -1)

        // Stop movement
        engine.player.moveLeft = false
        engine.player.moveRight = false
        engine.player.jumpPressed = false

        // Determine action based on hold time and drag distance
        if totalDrag < 20 {
            // Stationary touch — check hold vs tap
            if elapsed > 0.5 && engine.seeds > 0 {
                // Long press -> plant
                engine.plant(screenH: UIScreen.main.bounds.height)
                audio.playPlant()
            } else if elapsed < 0.25 {
                // Quick tap -> interact
                engine.interact(screenH: UIScreen.main.bounds.height)
                audio.playInteract()
            }
        } else if value.location.y - value.startLocation.y < -40 {
            // Swipe up was jump — already handled in onChanged
        }

        engine.touchInput.isHolding = false
        engine.touchInput.holdTime = 0
        engine.touchInput.justReleased = false  // handled inline above
        dragStart = nil
        dragCurrent = nil
        touchStartTime = nil
        isTouching = false
    }
}
