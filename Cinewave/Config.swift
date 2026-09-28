import UIKit

enum Config {
    static let name = "Cinewave"
    /// The web app. Change this if the public hostname changes.
    static let startURL = URL(string: "https://cinewave.nikolatesla.co.in")!
    /// Links under this domain stay in the app; everything else opens outside it.
    static let inAppDomain = "nikolatesla.co.in"
    /// The page detects the shell (and its version) from "<token>/<version>" in the user agent.
    static let userAgentToken = "CinewaveIOS"

    /// Google sign-in handoff: Cinewave's own server (cinewave/lib/app-handoff.js).
    static let authURL = URL(string: "https://cinewave.nikolatesla.co.in")!
    static let handoffApp = "cinewave"
    static let handoffScheme = "cinewave"

    static let background = UIColor(red: 0x0D / 255.0, green: 0x07 / 255.0, blue: 0x18 / 255.0, alpha: 1)
    static let accent = UIColor(red: 0xFF / 255.0, green: 0x7A / 255.0, blue: 0xA8 / 255.0, alpha: 1)

    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }
}
