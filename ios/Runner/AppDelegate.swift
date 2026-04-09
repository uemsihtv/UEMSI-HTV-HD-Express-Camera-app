import Flutter
import NetworkExtension
import UIKit

@main
@objc class AppDelegate: UIResponder, UIApplicationDelegate {
  private var flutterEngine: FlutterEngine?
  private var wifiJoinChannel: FlutterMethodChannel?
  private var deviceChannel: FlutterMethodChannel?

  var window: UIWindow?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Shows in Xcode console and Console.app even when Flutter logging is not up yet.
    NSLog("HDExpress AppDelegate didFinishLaunching")

    // iOS 26 workaround: avoid UIScene + implicit engine races by using classic
    // AppDelegate window setup with an explicit FlutterEngine.
    let engine = FlutterEngine(name: "main_engine")
    engine.run()
    GeneratedPluginRegistrant.register(with: engine)

    let messenger = engine.binaryMessenger
    installDeviceInfoChannel(messenger: messenger)
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
