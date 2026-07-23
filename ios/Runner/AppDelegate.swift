import Flutter
import NetworkExtension
import UIKit

@main
@objc class AppDelegate: UIResponder, UIApplicationDelegate {
  private var flutterEngine: FlutterEngine?
  private var wifiJoinChannel: FlutterMethodChannel?
  private var deviceChannel: FlutterMethodChannel?
  private var deviceWebChannel: FlutterMethodChannel?

  /// Kept alive while a preauth URLSession task is in flight.
  private var deviceWebAuthSession: URLSession?
  private var deviceWebAuthHelper: DeviceWebAuthHelper?

  var window: UIWindow?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Shows in Xcode console and Console.app even when Flutter logging is not up yet.
    NSLog("HDExpress AppDelegate didFinishLaunching")

    // iOS 26 workaround: avoid UIScene + implicit engine races by using classic
    // AppDelegate window setup with an explicit FlutterEngine.
    // Scene-based alternative (not built): see SceneDelegate.swift header comments.
    let engine = FlutterEngine(name: "main_engine")
    engine.run()
    GeneratedPluginRegistrant.register(with: engine)

    let messenger = engine.binaryMessenger
    installDeviceInfoChannel(messenger: messenger)
    installDeviceWebChannel(messenger: messenger)
    DispatchQueue.main.async { [weak self] in
      self?.installWifiJoinChannel(messenger: messenger)
    }

    let flutterViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = flutterViewController
    window.makeKeyAndVisible()
    self.window = window

    flutterEngine = engine

    return true
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

    // Seed common protection spaces before the challenge (helps when Safari
    // asks with a matching host/port before our session finishes).
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
      // 2xx/3xx = page reachable with auth; 401 still means challenge path ran.
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

  private func installWifiJoinChannel(messenger: FlutterBinaryMessenger) {
    NSLog("HDExpress installWifiJoinChannel")
    let channel = FlutterMethodChannel(name: "uemsi_wifi_joiner", binaryMessenger: messenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "joinWpa":
        guard
          let args = call.arguments as? [String: Any],
          let ssid = args["ssid"] as? String,
          let password = args["password"] as? String
        else {
          result(FlutterError(code: "bad_args", message: "Missing ssid/password", details: nil))
          return
        }

        let config = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
        config.joinOnce = false

        NEHotspotConfigurationManager.shared.apply(config) { error in
          if let e = error as NSError? {
            if e.domain == NEHotspotConfigurationErrorDomain,
               e.code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
              result(true)
              return
            }
            result(false)
            return
          }
          result(true)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    wifiJoinChannel = channel
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
