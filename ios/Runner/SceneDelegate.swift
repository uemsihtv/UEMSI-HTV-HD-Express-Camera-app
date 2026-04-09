import Flutter
import NetworkExtension
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  private var flutterEngine: FlutterEngine?

  /// Keeps method channels alive for the scene lifetime.
  private var wifiJoinChannel: FlutterMethodChannel?
  private var deviceChannel: FlutterMethodChannel?

  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    // Workaround for iOS 26.x crash in FlutterViewController viewDidLoad when using
    // implicit engine initialization (ProMotion / touch rate correction vsync client).
    let engine = FlutterEngine(name: "main_engine")
    engine.run()

    let flutterViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = flutterViewController
    self.window = window
    window.makeKeyAndVisible()

    // Register plugins after the engine is running and the view controller exists.
    // Using the engine as registry is the standard iOS embedding pattern.
    GeneratedPluginRegistrant.register(with: engine)

    let messenger = engine.binaryMessenger
    installDeviceInfoChannel(messenger: messenger)

    // Defer Wi‑Fi channel one turn so it isn't on the same stack as heavy plugins.
    DispatchQueue.main.async { [weak self] in
      self?.installWifiJoinChannel(messenger: messenger)
    }

    flutterEngine = engine
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
