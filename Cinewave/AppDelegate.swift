import AVFoundation
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // .playback (with UIBackgroundModes=audio): sound ignores the silent switch, keeps going with
        // the screen locked, and Picture in Picture works. Not activated here, so opening the app
        // doesn't stop whatever else was playing until a video starts.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        return true
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.backgroundColor = Config.background
        window.rootViewController = WebViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}
