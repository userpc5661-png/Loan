import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        MainActor.assumeIsolated {
            _ = DownloadCenter.shared
            DownloadCenter.shared.backgroundCompletion = completionHandler
        }
    }
}
