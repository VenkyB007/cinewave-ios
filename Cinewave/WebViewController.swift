import UIKit
import WebKit

/// WKWebView shell around the web app, plus what a web page can't do on its own inside an app:
/// Google sign-in, which Google refuses inside web views (SignInHandoff), saving movies and
/// photos to the Files app (Downloads), and links that leave the app for Safari or the app
/// they belong to.
final class WebViewController: UIViewController {

    private var webView: WKWebView!
    private let progress = UIProgressView(progressViewStyle: .bar)
    private let offline = UIStackView()
    private var progressWatch: NSKeyValueObservation?
    private let signIn = SignInHandoff()
    private let downloads = Downloads()

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // cookies + localStorage survive restarts
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.applicationNameForUserAgent = "Mobile/15E148 \(Config.userAgentToken)/\(Config.version)"

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = Config.background
        webView.scrollView.backgroundColor = Config.background
        webView.allowsBackForwardNavigationGestures = true
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true } // Safari → Develop menu on a Mac
        #endif

        let root = UIView()
        root.backgroundColor = Config.background
        for v in [webView!, progress, offline] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(v)
        }

        progress.progressTintColor = Config.accent
        progress.trackTintColor = .clear
        progress.isHidden = true

        let title = UILabel()
        title.text = "\(Config.name) is unreachable"
        title.font = .preferredFont(forTextStyle: .headline)
        title.textColor = .white
        let body = UILabel()
        body.text = "Check your internet connection, or the server may be offline."
        body.font = .preferredFont(forTextStyle: .subheadline)
        body.textColor = UIColor(white: 1, alpha: 0.7)
        body.numberOfLines = 0
        body.textAlignment = .center
        let retry = UIButton(type: .system)
        retry.setTitle("Retry", for: .normal)
        retry.tintColor = Config.accent
        retry.addTarget(self, action: #selector(reload), for: .touchUpInside)
        offline.axis = .vertical
        offline.alignment = .center
        offline.spacing = 12
        [title, body, retry].forEach(offline.addArrangedSubview)
        offline.backgroundColor = Config.background
        offline.isLayoutMarginsRelativeArrangement = true
        offline.isHidden = true

        NSLayoutConstraint.activate([
            // Full screen, safe areas handled by WebKit as in Safari: pages with viewport-fit=cover
            // draw under the notch themselves, the others are inset automatically.
            webView.topAnchor.constraint(equalTo: root.topAnchor),
            webView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            progress.topAnchor.constraint(equalTo: root.safeAreaLayoutGuide.topAnchor),
            progress.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            offline.topAnchor.constraint(equalTo: root.topAnchor),
            offline.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            offline.leadingAnchor.constraint(equalTo: root.layoutMarginsGuide.leadingAnchor),
            offline.trailingAnchor.constraint(equalTo: root.layoutMarginsGuide.trailingAnchor),
        ])
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        progressWatch = webView.observe(\.estimatedProgress) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.showProgress() } // KVO fires on the main thread
        }
        webView.load(URLRequest(url: Config.startURL))
    }

    private func showProgress() {
        let p = webView.estimatedProgress
        progress.setProgress(Float(p), animated: p > 0)
        progress.isHidden = p >= 1
    }

    @objc private func reload() {
        offline.isHidden = true
        if webView.url == nil { webView.load(URLRequest(url: Config.startURL)) } else { webView.reload() }
    }

    private func loadFailed(_ error: Error) {
        let e = error as NSError
        // Cancelled, or a navigation we took over ourselves (sign-in, links opened outside).
        if e.domain == NSURLErrorDomain && e.code == NSURLErrorCancelled { return }
        if e.domain == "WebKitErrorDomain" && e.code == 102 { return } // frame load interrupted by policy
        offline.isHidden = false
        progress.isHidden = true
    }

    private func startSignIn() {
        signIn.start(anchor: view.window) { [weak self] exchange in
            guard let exchange else { return } // closed the sheet: stay on the login page
            self?.webView.load(exchange)
        }
    }

    static func isInApp(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host?.lowercased() else { return false }
        return host == Config.inAppDomain || host.hasSuffix("." + Config.inAppDomain)
    }

    private func openOutside(_ url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = action.request.url else { return .cancel }
        switch url.scheme?.lowercased() {
        case "about", "blob", "data":
            return .allow
        case "http", "https":
            break
        default:
            openOutside(url) // tel:, mailto:, other players' schemes …
            return .cancel
        }
        // Embedded frames load in place; only where the whole app goes is our business.
        if action.targetFrame?.isMainFrame == false { return .allow }
        // A movie, photo or zip being saved (<a download>): a file to keep, not a page to show.
        if action.shouldPerformDownload && Self.isInApp(url) { return .download }
        if Self.isInApp(url) { return .allow }
        if SignInHandoff.isGoogleSignIn(url) {
            startSignIn()
            return .cancel
        }
        openOutside(url)
        return .cancel
    }

    /// A file the page can't show (an attachment, or a type WebKit has no viewer for, like .mkv)
    /// is saved instead of leaving a blank page: ?download=1 answers with Content-Disposition: attachment.
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        guard response.isForMainFrame, let url = response.response.url, Self.isInApp(url) else { return .allow }
        if !response.canShowMIMEType { return .download }
        if let http = response.response as? HTTPURLResponse,
           let disposition = http.value(forHTTPHeaderField: "Content-Disposition")?.lowercased(),
           disposition.hasPrefix("attachment") { return .download }
        return .allow
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = downloads
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = downloads
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        offline.isHidden = true
        showProgress()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progress.isHidden = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadFailed(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadFailed(error)
    }

    /// iOS kills the page's process under memory pressure (often in the background): bring it back.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        reload()
    }
}

extension WebViewController: WKUIDelegate {
    /// target=_blank / window.open: ours in this view, anything else outside.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url {
            if Self.isInApp(url) { webView.load(action.request) } else { openOutside(url) }
        }
        return nil
    }
}
