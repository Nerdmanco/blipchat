import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register our custom BLE advertising plugin
    if let controller = window?.rootViewController as? FlutterViewController {
      BleAdvertisingPlugin.register(with: registrar(forPlugin: "BleAdvertisingPlugin")!)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
