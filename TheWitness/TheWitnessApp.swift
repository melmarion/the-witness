import SwiftUI

@main
struct TheWitnessApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .ignoresSafeArea()
                .statusBarHidden()
                .preferredColorScheme(.dark)
        }
    }
}
