import AppKit
import WebKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: PlayerWindowController?
    private var pendingFile: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = PlayerWindowController()
        windowController = controller
        controller.showWindow(nil)

        if let pendingFile {
            controller.openTgs(url: pendingFile)
            self.pendingFile = nil
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }

        if let windowController {
            windowController.openTgs(url: url)
            windowController.showWindow(nil)
            windowController.window?.makeKeyAndOrderFront(nil)
        } else {
            pendingFile = url
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

