import SwiftUI

@main
struct NSMFlowApp: App {
    @StateObject private var session = FlowSession.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                // The keyboard opens nsmflow://start when no session is running.
                .onOpenURL { url in
                    guard url.scheme == "nsmflow" else { return }
                    Task { await session.openSession(thenRecord: url.host == "start") }
                }
        }
    }
}
