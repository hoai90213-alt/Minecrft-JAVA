import SwiftUI

@main
struct AmethystSwiftUIApp: App {
    @StateObject private var container = AppContainer(core: MockLauncherCore())

    var body: some Scene {
        WindowGroup {
            RootShellView()
                .environmentObject(container)
                .preferredColorScheme(.dark)
        }
    }
}
