import AppKit
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: PlayerWindowController?
    private var pendingFile: URL?

    func applicationWillFinishLaunching(_ notification: Notification) {
        AppLog.write("applicationWillFinishLaunching")
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.write("applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.regular)
        warnIfRunningFromMountedImage()

        let controller = PlayerWindowController()
        windowController = controller
        controller.showWindow(nil)
        controller.present()
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            AppLog.write("delayed present visibleWindows=\(NSApp.windows.filter { $0.isVisible }.count)")
            self?.windowController?.present()
            NSApp.activate(ignoringOtherApps: true)
        }

        if let pendingFile {
            controller.openTgs(url: pendingFile)
            self.pendingFile = nil
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        AppLog.write("open urls count=\(urls.count)")
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppLog.write("handleReopen hasVisibleWindows=\(flag)")
        if !flag {
            windowController?.showWindow(nil)
            windowController?.present()
        }
        return true
    }

    private func warnIfRunningFromMountedImage() {
        let appPath = Bundle.main.bundleURL.path
        AppLog.write("bundlePath=\(appPath)")
        guard appPath.hasPrefix("/Volumes/") else { return }

        let alert = NSAlert()
        alert.messageText = "TGSPlayer is running from DMG"
        alert.informativeText = "Drag TGSPlayer.app into Applications and run it from there. Running directly from DMG can crash if macOS unmounts the image."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

enum AppLog {
    static let url = URL(fileURLWithPath: "/tmp/TGSPlayer.log")

    static func write(_ message: String) {
        let line = "TGSPlayer: \(Date()) \(message)\n"
        NSLog("%@", line)
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }
}
