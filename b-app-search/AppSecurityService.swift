//
//  AppSecurityService.swift
//  b-app-search
//

import CryptoKit
import Foundation
import LocalAuthentication

enum AppSecurityService {
  static let faceIDEnabledKey = "securityFaceIDEnabled"
  static let passcodeEnabledKey = "securityPasscodeEnabled"
  private static let passcodeKeychainAccount = "com.b-app-search.passcode"

  static var isPasscodeEnabled: Bool {
    UserDefaults.standard.bool(forKey: passcodeEnabledKey) && hasStoredPasscode
  }

  static var isFaceIDEnabled: Bool {
    UserDefaults.standard.bool(forKey: faceIDEnabledKey)
  }

  static var hasStoredPasscode: Bool {
    loadPasscodeHash() != nil
  }

  static var biometryType: LABiometryType {
    let context = LAContext()
    _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    return context.biometryType
  }

  static var biometryTitle: String {
    switch biometryType {
    case .faceID: return "Face ID"
    case .touchID: return "Touch ID"
//    case .opticID: return "Optic ID"
    default: return "生物识别"
    }
  }

  static var isBiometryAvailable: Bool {
    let context = LAContext()
    return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
  }

  static func setPasscode(_ code: String) -> Bool {
    guard code.count >= 4, code.allSatisfy(\.isNumber) else { return false }
    guard savePasscodeHash(hashPasscode(code)) else { return false }
    UserDefaults.standard.set(true, forKey: passcodeEnabledKey)
    return true
  }

  static func verifyPasscode(_ code: String) -> Bool {
    guard let stored = loadPasscodeHash() else { return false }
    return stored == hashPasscode(code)
  }

  @discardableResult
  static func disablePasscode(confirmCode: String) -> Bool {
    guard verifyPasscode(confirmCode) else { return false }
    deletePasscodeHash()
    UserDefaults.standard.set(false, forKey: passcodeEnabledKey)
    UserDefaults.standard.set(false, forKey: faceIDEnabledKey)
    return true
  }

  static func setFaceIDEnabled(_ enabled: Bool) async -> Result<Void, SecurityAuthError> {
    if enabled {
      guard isPasscodeEnabled else {
        return .failure(.passcodeRequired)
      }
      guard isBiometryAvailable else {
        return .failure(.biometryUnavailable)
      }
      let success = await authenticateWithBiometry(reason: "开启 \(biometryTitle) 解锁")
      guard success else { return .failure(.biometryFailed) }
      UserDefaults.standard.set(true, forKey: faceIDEnabledKey)
      return .success(())
    }

    UserDefaults.standard.set(false, forKey: faceIDEnabledKey)
    return .success(())
  }

  static func authenticateWithBiometry(reason: String) async -> Bool {
    await withCheckedContinuation { continuation in
      let context = LAContext()
      context.localizedCancelTitle = "取消"
      context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
        continuation.resume(returning: success)
      }
    }
  }

  static func authenticateForAppUnlock(reason: String) async -> Bool {
    if isFaceIDEnabled, isBiometryAvailable {
      return await authenticateWithBiometry(reason: reason)
    }
    return false
  }

  private static func hashPasscode(_ code: String) -> String {
    let digest = SHA256.hash(data: Data(code.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  private static func savePasscodeHash(_ hash: String) -> Bool {
    deletePasscodeHash()
    let data = Data(hash.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: passcodeKeychainAccount,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      kSecValueData as String: data
    ]
    return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
  }

  private static func loadPasscodeHash() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: passcodeKeychainAccount,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func deletePasscodeHash() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: passcodeKeychainAccount
    ]
    SecItemDelete(query as CFDictionary)
  }
}

enum SecurityAuthError: LocalizedError {
  case passcodeRequired
  case biometryUnavailable
  case biometryFailed
  case passcodeMismatch
  case invalidPasscode

  var errorDescription: String? {
    switch self {
    case .passcodeRequired: return "请先开启 App 密码。"
    case .biometryUnavailable: return "当前设备不支持生物识别。"
    case .biometryFailed: return "生物识别验证失败。"
    case .passcodeMismatch: return "两次输入的密码不一致。"
    case .invalidPasscode: return "密码至少 4 位数字。"
    }
  }
}

enum PasscodeSetupMode {
  case create
  case change
  case disable
}
