import Flutter
import UIKit

/// Owns the single window for this app.
///
/// The window is created from the connecting `UIWindowScene`, not from
/// `UIScreen.main`, so it tracks whichever iPhone Duo display is active and
/// resizes when the device is folded or unfolded.
///
/// The engine is explicit. An implicit `FlutterViewController` (storyboard /
/// nib) crashed in `viewDidLoad` on iOS 26 around the ProMotion vsync client.
/// Do not add `UISceneStoryboardFile` to the scene manifest: that would load
/// `Main.storyboard` and start a second, implicit engine.
class SceneDelegate: UIResponder, UIWindowSceneDelegate, FlutterSceneLifeCycleProvider {
  let sceneLifeCycleDelegate = FlutterPluginSceneLifeCycleDelegate()

  private var flutterEngine: FlutterEngine?
  private var deviceChannel: FlutterMethodChannel?
  private var deviceWebChannel: FlutterMethodChannel?

  /// Kept alive while a preauth URLSession task is in flight.
  private var deviceWebAuthSession: URLSession?
  private var deviceWebAuthHelper: DeviceWebAuthHelper?

  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    NSLog("HDExpress SceneDelegate willConnect")

    let engine = FlutterEngine(name: "main_engine")
    engine.run()
    GeneratedPluginRegistrant.register(with: engine)

    let messenger = engine.binaryMessenger
    installDeviceInfoChannel(messenger: messenger)
    installDeviceWebChannel(messenger: messenger)
    let flutterViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    flutterViewController.edgesForExtendedLayout = .all
    flutterViewController.extendedLayoutIncludesOpaqueBars = true
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = flutterViewController
    self.window = window
    window.makeKeyAndVisible()
    flutterEngine = engine

    // Forward after the view is in the hierarchy so plugins can see this scene.
    sceneLifeCycleDelegate.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneDidDisconnect(scene)
  }

  func sceneWillEnterForeground(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneWillEnterForeground(scene)
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneDidBecomeActive(scene)
  }

  func sceneWillResignActive(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneWillResignActive(scene)
  }

  func sceneDidEnterBackground(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneDidEnterBackground(scene)
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    sceneLifeCycleDelegate.scene(scene, openURLContexts: URLContexts)
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    sceneLifeCycleDelegate.scene(scene, continue: userActivity)
  }

  func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    sceneLifeCycleDelegate.windowScene(
      windowScene,
      performActionFor: shortcutItem,
      completionHandler: completionHandler
    )
  }

  private func installDeviceInfoChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "uemsi_device_info", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "isSimulator" else {
        result(FlutterMethodNotImplemented)
        return
      }
      #if targetEnvironment(simulator)
      result(true)
      #else
      result(false)
      #endif
    }
    deviceChannel = channel
  }

  /// Seeds shared URLCredentialStorage so Safari can auto-fill HTTP Basic Auth
  /// for the transmitter web UI (iPhone often strips user:pass from URLs).
  private func installDeviceWebChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "uemsi_device_web", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "preauthDeviceWebUi" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.preauthDeviceWebUi(result: result)
    }
    deviceWebChannel = channel
  }

  private func preauthDeviceWebUi(result: @escaping FlutterResult) {
    guard let url = URL(string: "http://192.168.0.1/") else {
      result(false)
      return
    }

    seedDeviceWebCredentials(host: "192.168.0.1", port: 80, realm: nil)
    seedDeviceWebCredentials(host: "192.168.0.1", port: 80, realm: "")

    let helper = DeviceWebAuthHelper()
    let session = URLSession(
      configuration: .ephemeral,
      delegate: helper,
      delegateQueue: OperationQueue.main
    )
    deviceWebAuthHelper = helper
    deviceWebAuthSession = session

    var request = URLRequest(url: url, timeoutInterval: 5)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    let token = Data("admin:123456".utf8).base64EncodedString()
    request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")

    let task = session.dataTask(with: request) { [weak self] _, response, _ in
      defer {
        session.finishTasksAndInvalidate()
        self?.deviceWebAuthSession = nil
        self?.deviceWebAuthHelper = nil
      }
      let status = (response as? HTTPURLResponse)?.statusCode ?? -1
      let ok = (200..<400).contains(status) || status == 401
      DispatchQueue.main.async {
        result(ok)
      }
    }
    task.resume()
  }

  private func seedDeviceWebCredentials(host: String, port: Int, realm: String?) {
    let space = URLProtectionSpace(
      host: host,
      port: port,
      protocol: "http",
      realm: realm,
      authenticationMethod: NSURLAuthenticationMethodHTTPBasic
    )
    let credential = URLCredential(
      user: "admin",
      password: "123456",
      persistence: .permanent
    )
    URLCredentialStorage.shared.setDefaultCredential(credential, for: space)
  }

}

/// Handles HTTP Basic Auth challenges and persists credentials for Safari.
private final class DeviceWebAuthHelper: NSObject, URLSessionTaskDelegate {
  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic
    else {
      completionHandler(.performDefaultHandling, nil)
      return
    }

    let credential = URLCredential(
      user: "admin",
      password: "123456",
      persistence: .permanent
    )
    URLCredentialStorage.shared.setDefaultCredential(
      credential,
      for: challenge.protectionSpace
    )
    completionHandler(.useCredential, credential)
  }
}
