import SwiftUI
import UIKit
import os
@main
struct LumenApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        Task {
            do {
                try await KnowledgeStorage.shared.initialize()
            } catch {
                KnowledgeLogger.storage.error("KnowledgeStorage init failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            BrowserView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        URLCache.shared = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024
        )
        _ = TrackerDatabase.shared
        return true
    }

    func application(
        _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .portrait
    }
}
