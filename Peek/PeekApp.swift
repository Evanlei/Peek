import SwiftUI

@main
struct PeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Peek lives entirely in the notch panel; no regular windows.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let fake = ProcessInfo.processInfo.environment["PEEK_FAKE"] == "1"
        controller = NotchController(store: fake ? AgentStore.fake() : AgentStore.live())
    }
}
