import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static let storageChannelName = "ro.contacteduplicate.app/storage"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let storageChannel = FlutterMethodChannel(
        name: Self.storageChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      storageChannel.setMethodCallHandler { call, result in
        guard call.method == "excludeFromBackup" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard
          let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String,
          !path.isEmpty
        else {
          result(
            FlutterError(
              code: "invalid_path",
              message: "Calea fisierului este invalida.",
              details: nil
            )
          )
          return
        }

        do {
          var resourceValues = URLResourceValues()
          resourceValues.isExcludedFromBackup = true
          var resourceUrl = URL(fileURLWithPath: path)
          try resourceUrl.setResourceValues(resourceValues)
          result(true)
        } catch {
          result(
            FlutterError(
              code: "exclude_from_backup_failed",
              message: "Resursa nu a putut fi exclusa din backupul sistemului.",
              details: nil
            )
          )
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
