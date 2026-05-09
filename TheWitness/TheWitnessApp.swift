import SwiftUI

@main
struct TheWitnessApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .statusBarHidden()
                .preferredColorScheme(.dark)
        }
    }
}
