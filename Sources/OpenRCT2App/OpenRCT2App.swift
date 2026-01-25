// OpenRCT2App - iOS entry point
import SwiftUI

@main
struct OpenRCT2App: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .ignoresSafeArea()
        }
    }
}
