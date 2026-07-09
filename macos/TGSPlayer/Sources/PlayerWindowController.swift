import AppKit
import UniformTypeIdentifiers
import WebKit

final class PlayerWindowController: NSWindowController, WKScriptMessageHandler, NSWindowDelegate {
    private let webView: WKWebView
    private var currentURL: URL?
    private var folderFiles: [URL] = []

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(WeakScriptMessageHandler(), name: "tgsPlayer")
        webView = WKWebView(frame: .zero, configuration: configuration)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 360),
            styleMask: [.borderless, .resizable, .miniaturizable, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.minSize = NSSize(width: 560, height: 280)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.title = "TGSPlayer"
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false

        super.init(window: window)
        WeakScriptMessageHandler.target = self
        window.delegate = self
        window.contentView = webView
        webView.wantsLayer = true
        webView.layer?.cornerRadius = 17
        webView.layer?.masksToBounds = true
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false

        if let html = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Resources") {
            webView.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func openTgs(url: URL) {
        guard url.pathExtension.lowercased() == "tgs" else { return }

        currentURL = url
        refreshFolder(for: url)
        resizeForViewer()

        do {
            let data = try Data(contentsOf: url)
            let base64 = data.base64EncodedString()
            let script = "window.loadTgsGzipBase64('\(base64)')"
            webView.evaluateJavaScript(script)
        } catch {
            webView.evaluateJavaScript("window.showLogoFallback()")
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            let body = message.body as? [String: Any],
            let type = body["type"] as? String
        else { return }

        if type == "drag" {
            window?.performDrag(with: NSApp.currentEvent!)
            return
        }

        if type == "pick-file" {
            pickFile()
            return
        }

        if type == "folder-next" {
            moveInFolder(1)
            return
        }

        if type == "folder-prev" {
            moveInFolder(-1)
            return
        }

        guard
            type == "window",
            let payload = body["payload"] as? [String: Any],
            let action = payload["action"] as? String
        else { return }

        switch action {
        case "minimize":
            window?.miniaturize(nil)
        case "fullscreen":
            window?.toggleFullScreen(nil)
        case "close":
            window?.close()
        default:
            break
        }
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "tgs")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.openTgs(url: url)
        }
    }

    private func refreshFolder(for url: URL) {
        do {
            let directory = url.deletingLastPathComponent()
            folderFiles = try FileManager.default
                .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "tgs" }
                .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        } catch {
            folderFiles = []
        }
    }

    private func moveInFolder(_ direction: Int) {
        guard
            let currentURL,
            folderFiles.count > 1,
            let index = folderFiles.firstIndex(of: currentURL)
        else { return }

        let next = (index + direction + folderFiles.count) % folderFiles.count
        openTgs(url: folderFiles[next])
    }

    private func resizeForViewer() {
        guard let window else { return }
        var frame = window.frame
        frame.size = NSSize(width: 620, height: 560)
        window.setFrame(frame, display: true, animate: true)
        window.center()
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    static weak var target: WKScriptMessageHandler?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Self.target?.userContentController(userContentController, didReceive: message)
    }
}
