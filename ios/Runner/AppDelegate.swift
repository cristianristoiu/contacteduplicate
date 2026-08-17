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
      storageChannel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "excludeFromBackup" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard
          let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String,
          !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
          guard let protectedUrl = try self?.validatedInternalBackupUrl(path: path) else {
            throw StorageProtectionError.invalidPath
          }
          var resourceValues = URLResourceValues()
          resourceValues.isExcludedFromBackup = true
          var mutableUrl = protectedUrl
          try mutableUrl.setResourceValues(resourceValues)
          let verifiedValues = try mutableUrl.resourceValues(forKeys: [.isExcludedFromBackupKey])
          guard verifiedValues.isExcludedFromBackup == true else {
            throw StorageProtectionError.verificationFailed
          }
          result(true)
        } catch StorageProtectionError.invalidPath {
          result(
            FlutterError(
              code: "unauthorized_path",
              message: "Calea nu apartine directorului intern autorizat pentru backupuri.",
              details: nil
            )
          )
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

  private func validatedInternalBackupUrl(path: String) throws -> URL {
    let fileManager = FileManager.default
    guard let supportRoot = fileManager.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else {
      throw StorageProtectionError.invalidPath
    }

    let allowedRoot = supportRoot
      .appendingPathComponent("contact_backups", isDirectory: true)
      .standardizedFileURL
      .resolvingSymlinksInPath()
    let candidate = URL(fileURLWithPath: path)
      .standardizedFileURL
      .resolvingSymlinksInPath()

    let allowedPath = allowedRoot.path.hasSuffix("/") ? allowedRoot.path : allowedRoot.path + "/"
    let candidatePath = candidate.path
    guard candidatePath == allowedRoot.path || candidatePath.hasPrefix(allowedPath) else {
      throw StorageProtectionError.invalidPath
    }

    return candidate
  }
}

private enum StorageProtectionError: Error {
  case invalidPath
  case verificationFailed
}
