//
//  AlipayAuthService.swift
//  b-app-search
//
//  支付宝授权登录：服务端下发签名 authInfo → SDK auth_v2 → auth_code → 后端换会话。
//

import Foundation
import UIKit

final class AlipayAuthService {
  static let shared = AlipayAuthService()

  private var authContinuation: CheckedContinuation<String, Error>?

  private init() {}

  var isSDKAvailable: Bool {
    AlipaySDKBridge.isSDKAvailable()
  }

  func configure() {
    // AlipaySDK 无需像微信一样提前 register；保留入口便于统一初始化。
    _ = AuthConfig.isAlipayConfigured
  }

  /// 返回支付宝授权 `auth_code`。校验顺序与微信登录保持一致。
  func signIn() async throws -> String {
    guard AuthConfig.isAlipayConfigured else {
      throw AuthError.notConfigured("支付宝")
    }
    guard AlipaySDKBridge.isSDKAvailable() else {
      throw AuthError.notConfigured("支付宝")
    }
    guard AlipaySDKBridge.isAlipayAppInstalled() else {
      throw AuthError.alipayNotInstalled
    }

    let authInfo = try await BackendAPI.Auth.fetchAlipayAuthInfo()
    guard !authInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AuthError.alipayFailed("无法唤起支付宝")
    }

    return try await withCheckedThrowingContinuation { continuation in
      authContinuation = continuation
      AlipaySDKBridge.auth(
        withInfo: authInfo,
        scheme: AuthConfig.alipayURLScheme
      ) { [weak self] result, error in
        guard let self else { return }
        if let error {
          self.finishAuth(result: nil, error: AuthError.alipayFailed("无法唤起支付宝"))
          return
        }
        self.finishAuth(result: result, error: nil)
      }
    }
  }

  @discardableResult
  func handleOpenURL(_ url: URL) -> Bool {
    // 仅处理本应用支付宝回跳 scheme，避免误抢其他 SDK 的 URL。
    guard url.scheme?.lowercased() == AuthConfig.alipayURLScheme.lowercased() else {
      return false
    }

    return AlipaySDKBridge.handleOpen(url) { [weak self] result, error in
      self?.finishAuth(result: result, error: error)
    }
  }

  private func finishAuth(result: [AnyHashable: Any]?, error: Error?) {
    defer { authContinuation = nil }

    if let error {
      if let authError = error as? AuthError {
        authContinuation?.resume(throwing: authError)
      } else {
        authContinuation?.resume(throwing: AuthError.alipayFailed(error.localizedDescription))
      }
      return
    }

    do {
      let code = try Self.parseAuthCode(from: result ?? [:])
      authContinuation?.resume(returning: code)
    } catch {
      authContinuation?.resume(throwing: error)
    }
  }

  static func parseAuthCode(from result: [AnyHashable: Any]) throws -> String {
    let status = stringValue(result["resultStatus"]) ?? ""
    if status == "6001" {
      throw AuthError.cancelled
    }
    guard status == "9000" else {
      let memo = stringValue(result["memo"])
      throw AuthError.alipayFailed(memo ?? "支付宝授权失败，请重试。")
    }

    if let direct = stringValue(result["auth_code"]), !direct.isEmpty {
      return direct
    }

    if let resultString = stringValue(result["result"]) {
      if let code = queryValue("auth_code", in: resultString), !code.isEmpty {
        return code
      }
    }

    throw AuthError.alipayFailed("支付宝授权失败，请重试。")
  }

  private static func stringValue(_ value: Any?) -> String? {
    if let string = value as? String { return string }
    if let number = value as? NSNumber { return number.stringValue }
    return nil
  }

  private static func queryValue(_ key: String, in query: String) -> String? {
    let normalized = query.replacingOccurrences(of: "?", with: "&")
    for pair in normalized.split(separator: "&") {
      let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { continue }
      if parts[0] == key {
        return parts[1].removingPercentEncoding ?? parts[1]
      }
    }
    return nil
  }
}
