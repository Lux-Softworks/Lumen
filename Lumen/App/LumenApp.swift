import SwiftUI
import UIKit
import os
@main
struct LumenApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var bootstrap = AppBootstrap.shared

    init() {
        AppBootstrap.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            BrowserView()
                .environmentObject(bootstrap)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    private static var prewarmTextField: UITextField?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        DispatchQueue.global(qos: .utility).async {
            URLCache.shared = URLCache(
                memoryCapacity: 32 * 1024 * 1024,
                diskCapacity: 256 * 1024 * 1024
            )
        }
        Self.prewarmKeyboardWhenReady()
        return true
    }

    func application(
        _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .portrait
    }

    private static func prewarmKeyboardWhenReady() {
        DispatchQueue.main.async {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState != .unattached })
            let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first
            guard let window else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    prewarmKeyboardWhenReady()
                }
                return
            }
            let tf = UITextField(frame: CGRect(x: -200, y: -200, width: 1, height: 1))
            window.addSubview(tf)
            prewarmTextField = tf
            tf.becomeFirstResponder()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tf.resignFirstResponder()
                tf.removeFromSuperview()
                prewarmTextField = nil
            }
        }
    }
}
