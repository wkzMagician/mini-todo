import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launchResult = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Initializes the callbackDispatcher running inside the app's own Flutter engine
    // when a background task fires, rather than spawning a second full engine.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    // Registers the BGTaskScheduler launch handler for the periodic sync task.
    // This must happen before didFinishLaunchingWithOptions returns, otherwise iOS
    // aborts the app when the task identifier is submitted asynchronously.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "dartloom.sync.default.periodic"
    )

    return launchResult
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}