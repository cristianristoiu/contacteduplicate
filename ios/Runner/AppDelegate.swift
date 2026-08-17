import Contacts
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static let storageChannelName = "ro.contacteduplicate.app/storage"
  private static let contactsChannelName = "ro.contacteduplicate.app/contacts"
  private static let maxContactBatch = 100
  private static let maxIdentifierLength = 256
  private static let maxOperationTokenLength = 96

  private let contactStore = CNContactStore()
  private let contactsQueue = DispatchQueue(
    label: "ro.contacteduplicate.app.contacts",
    qos: .userInitiated
  )

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      configureStorageChannel(controller)
      configureContactsChannel(controller)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureStorageChannel(_ controller: FlutterViewController) {
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

  private func configureContactsChannel(_ controller: FlutterViewController) {
    let contactsChannel = FlutterMethodChannel(
      name: Self.contactsChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    contactsChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(
          FlutterError(
            code: "contacts_bridge_unavailable",
            message: "Contactele nu sunt disponibile.",
            details: nil
          )
        )
        return
      }
      switch call.method {
      case "getContactCapabilities":
        self.handleContactCapabilities(call: call, result: result)
      case "preflightContacts":
        self.handleContactsPreflight(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func handleContactCapabilities(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let arguments = call.arguments as? [String: Any],
          let rawIdentifier = arguments["contactId"] as? String,
          let identifier = validatedContactIdentifier(rawIdentifier) else {
      result(
        FlutterError(
          code: "contact_id_invalid",
          message: "Identificatorul contactului este invalid.",
          details: nil
        )
      )
      return
    }

    contactsQueue.async { [weak self] in
      guard let self = self else { return }
      let payload = self.contactCapabilityPayload(identifier: identifier)
      DispatchQueue.main.async { result(payload) }
    }
  }

  private func handleContactsPreflight(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let arguments = call.arguments as? [String: Any],
          let rawIds = arguments["contactIds"] as? [String],
          let operationTokenRaw = arguments["operationToken"] as? String,
          let operationToken = validatedOperationToken(operationTokenRaw),
          !rawIds.isEmpty,
          rawIds.count <= Self.maxContactBatch else {
      result(
        FlutterError(
          code: "contact_batch_invalid",
          message: "Lista contactelor este invalida.",
          details: nil
        )
      )
      return
    }

    let identifiers = rawIds.compactMap(validatedContactIdentifier)
    guard identifiers.count == rawIds.count,
          Set(identifiers).count == identifiers.count else {
      result(
        FlutterError(
          code: "contact_batch_invalid",
          message: "Lista contactelor este invalida.",
          details: nil
        )
      )
      return
    }

    let requiresWrite = arguments["requiresWrite"] as? Bool ?? false
    if requiresWrite {
      // Contacts.framework nu expune o garantie publica de writability per contact.
      // Fail closed: iOS ramane copy-only pana la o dovada publica verificabila.
      result(
        FlutterError(
          code: "contacts_write_capability_unknown",
          message: "Stergerea sigura nu poate fi garantata pe iOS.",
          details: nil
        )
      )
      return
    }

    contactsQueue.async { [weak self] in
      guard let self = self else { return }
      let authorization = CNContactStore.authorizationStatus(for: .contacts)
      guard authorization == .authorized || self.isLimitedAuthorization(authorization) else {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "contacts_read_permission_denied",
              message: "Accesul la contacte este necesar.",
              details: nil
            )
          )
        }
        return
      }

      let payloads = identifiers.map { self.contactCapabilityPayload(identifier: $0) }
      let batchFingerprint = self.stableFingerprint(
        payloads.enumerated().map { index, payload in
          let found = payload["found"] as? Bool == true ? "1" : "0"
          let fingerprint = payload["metadataFingerprint"] as? String ?? ""
          return "\(index):\(found):\(fingerprint)"
        }.joined(separator: "|")
      )
      DispatchQueue.main.async {
        result([
          "operationToken": operationToken,
          "count": payloads.count,
          "contacts": payloads,
          "batchFingerprint": batchFingerprint,
        ])
      }
    }
  }

  private func contactCapabilityPayload(identifier: String) -> [String: Any] {
    let authorization = CNContactStore.authorizationStatus(for: .contacts)
    guard authorization == .authorized || isLimitedAuthorization(authorization) else {
      return [
        "found": false,
        "isProfile": false,
        "rawContactCount": 0,
        "update": "unknown",
        "delete": "unknown",
        "hasMixedCapabilities": false,
        "metadataFingerprint": stableFingerprint("denied"),
      ]
    }

    do {
      let keys: [CNKeyDescriptor] = [CNContactIdentifierKey as CNKeyDescriptor]
      let contact = try contactStore.unifiedContact(
        withIdentifier: identifier,
        keysToFetch: keys
      )
      let fingerprint = stableFingerprint("found:\(contact.identifier)")
      return [
        "found": true,
        "isProfile": false,
        "rawContactCount": 1,
        "update": "unknown",
        "delete": "unknown",
        "hasMixedCapabilities": false,
        "metadataFingerprint": fingerprint,
      ]
    } catch let error as CNError where error.code == .recordDoesNotExist {
      return [
        "found": false,
        "isProfile": false,
        "rawContactCount": 0,
        "update": "unknown",
        "delete": "unknown",
        "hasMixedCapabilities": false,
        "metadataFingerprint": stableFingerprint("missing"),
      ]
    } catch {
      return [
        "found": false,
        "isProfile": false,
        "rawContactCount": 0,
        "update": "unknown",
        "delete": "unknown",
        "hasMixedCapabilities": false,
        "metadataFingerprint": stableFingerprint("unavailable"),
      ]
    }
  }

  private func validatedContactIdentifier(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          trimmed.count <= Self.maxIdentifierLength,
          !trimmed.contains("\n"),
          !trimmed.contains("\r") else {
      return nil
    }
    return trimmed
  }

  private func validatedOperationToken(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 8,
          trimmed.count <= Self.maxOperationTokenLength,
          trimmed.range(of: "^[a-z][a-z0-9_-]+$", options: .regularExpression) != nil else {
      return nil
    }
    return trimmed
  }

  private func isLimitedAuthorization(_ status: CNAuthorizationStatus) -> Bool {
    if #available(iOS 18.0, *) {
      return status.rawValue == 4
    }
    return false
  }

  private func stableFingerprint(_ value: String) -> String {
    // FNV-1a 64-bit este suficient aici pentru un token local de detectare a schimbarii.
    // Nu este folosit pentru criptografie sau autentificare.
    var hash: UInt64 = 14695981039346656037
    for byte in value.utf8 {
      hash ^= UInt64(byte)
      hash &*= 1099511628211
    }
    return String(format: "%016llx", hash)
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
