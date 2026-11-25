import UIKit

@main
@objc class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Shows in Xcode console and Console.app even when Flutter logging is not up yet.
    NSLog("HDExpress AppDelegate didFinishLaunching")
    // The window is created in SceneDelegate and attached to the connecting
    // UIWindowScene. UIScreen.main is ambiguous on iPhone Duo (outer and inner
    // displays), and a window sized from it does not follow a fold.
    return true
  }
}
