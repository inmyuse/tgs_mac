import AppKit
import QuickLookThumbnailing
import WebKit

final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        let size = request.maximumSize
        let url = request.fileURL

        DispatchQueue.main.async {
            self.renderThumbnail(fileURL: url, size: size) { image in
                if let image {
                    handler(QLThumbnailReply(contextSize: size) { context in
                        NSGraphicsContext.saveGraphicsState()
                        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
                        image.draw(in: NSRect(origin: .zero, size: size))
                        NSGraphicsContext.restoreGraphicsState()
                        return true
                    }, nil)
                    return
                }

                handler(self.logoReply(size: size), nil)
            }
        }
    }

    private func renderThumbnail(fileURL: URL, size: CGSize, completion: @escaping (NSImage?) -> Void) {
        guard
            let html = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Resources"),
            let data = try? Data(contentsOf: fileURL)
        else {
            completion(nil)
            return
        }

        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(origin: .zero, size: size), configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")

        let renderer = ThumbnailRenderer(webView: webView, htmlURL: html, fileData: data, completion: completion)
        renderer.start()
    }

    private func logoReply(size: CGSize) -> QLThumbnailReply {
        QLThumbnailReply(contextSize: size) { context in
            guard let image = NSImage(named: "logo") else { return false }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            let scale = min(size.width / image.size.width, size.height / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let rect = CGRect(
                x: (size.width - drawSize.width) / 2,
                y: (size.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            image.draw(in: rect)
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
    }
}

private final class ThumbnailRenderer: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let htmlURL: URL
    private let fileData: Data
    private let completion: (NSImage?) -> Void
    private var didComplete = false

    init(webView: WKWebView, htmlURL: URL, fileData: Data, completion: @escaping (NSImage?) -> Void) {
        self.webView = webView
        self.htmlURL = htmlURL
        self.fileData = fileData
        self.completion = completion
        super.init()
        self.webView.navigationDelegate = self
    }

    func start() {
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.finish(nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let base64 = fileData.base64EncodedString()
        webView.evaluateJavaScript("document.body.classList.add('thumbnail'); window.loadTgsGzipBase64('\(base64)')") { [weak self] _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                self?.snapshot()
            }
        }
    }

    private func snapshot() {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = webView.bounds
        webView.takeSnapshot(with: configuration) { [weak self] image, _ in
            self?.finish(image)
        }
    }

    private func finish(_ image: NSImage?) {
        guard !didComplete else { return }
        didComplete = true
        completion(image)
    }
}

