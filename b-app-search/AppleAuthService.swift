//
//  AppleAuthService.swift
//  b-app-search
//

import AuthenticationServices
import UIKit

struct AppleAuthCredentialPayload {
  let userIdentifier: String
  let identityToken: String
  let authorizationCode: String?
  let email: String?
  let fullName: String?
}

@MainActor
final class AppleAuthService: NSObject {
  static let shared = AppleAuthService()

  private var continuation: CheckedContinuation<AppleAuthCredentialPayload, Error>?

  private override init() {
    super.init()
  }

  func signIn() async throws -> AppleAuthCredentialPayload {
    try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation

      let provider = ASAuthorizationAppleIDProvider()
      let request = provider.createRequest()
      request.requestedScopes = [.fullName, .email]

      let controller = ASAuthorizationController(authorizationRequests: [request])
      controller.delegate = self
      controller.presentationContextProvider = self
      controller.performRequests()
    }
  }

  func credentialPayload(from authorization: ASAuthorization) throws -> AppleAuthCredentialPayload {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      throw AuthError.appleFailed("授权凭证无效")
    }
    return try payload(from: credential)
  }

  func restorePreviousSignIn(completion: @escaping (Bool) -> Void) {
    guard
      let userID = UserDefaults.standard.string(forKey: UserSession.appleUserIDKey),
      !userID.isEmpty
    else {
      completion(false)
      return
    }

    let provider = ASAuthorizationAppleIDProvider()
    provider.getCredentialState(forUserID: userID) { state, _ in
      Task { @MainActor in
        switch state {
        case .authorized:
          if UserSession.isLoggedIn {
            completion(true)
          } else {
            let nickname = UserDefaults.standard.string(forKey: UserSession.userNicknameKey) ?? "Apple 用户"
            let email = UserDefaults.standard.string(forKey: UserSession.userEmailKey)
            UserSession.signIn(nickname: nickname, email: email, appleUserID: userID)
            completion(true)
          }
        default:
          UserDefaults.standard.removeObject(forKey: UserSession.appleUserIDKey)
          completion(false)
        }
      }
    }
  }

  private func finish(with result: Result<AppleAuthCredentialPayload, Error>) {
    guard let continuation else { return }
    self.continuation = nil
    switch result {
    case .success(let payload):
      continuation.resume(returning: payload)
    case .failure(let error):
      continuation.resume(throwing: error)
    }
  }

  private func payload(from credential: ASAuthorizationAppleIDCredential) throws -> AppleAuthCredentialPayload {
    guard
      let tokenData = credential.identityToken,
      let identityToken = String(data: tokenData, encoding: .utf8),
      !identityToken.isEmpty
    else {
      throw AuthError.appleFailed("无法读取 Apple 身份令牌")
    }

    let codeString: String?
    if let codeData = credential.authorizationCode {
      codeString = String(data: codeData, encoding: .utf8)
    } else {
      codeString = nil
    }

    let fullName = formattedName(from: credential.fullName)

    return AppleAuthCredentialPayload(
      userIdentifier: credential.user,
      identityToken: identityToken,
      authorizationCode: codeString,
      email: credential.email,
      fullName: fullName
    )
  }

  private func formattedName(from components: PersonNameComponents?) -> String? {
    guard let components else { return nil }
    let formatter = PersonNameComponentsFormatter()
    let formatted = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
    return formatted.isEmpty ? nil : formatted
  }
}

extension AppleAuthService: ASAuthorizationControllerDelegate {
  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      finish(with: .failure(AuthError.appleFailed("授权凭证无效")))
      return
    }

    do {
      let payload = try payload(from: credential)
      finish(with: .success(payload))
    } catch {
      finish(with: .failure(error))
    }
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    let nsError = error as NSError
    if nsError.domain == ASAuthorizationError.errorDomain,
       nsError.code == ASAuthorizationError.canceled.rawValue
    {
      finish(with: .failure(AuthError.cancelled))
      return
    }
    finish(with: .failure(AuthError.appleFailed(error.localizedDescription)))
  }
}

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow } ?? ASPresentationAnchor()
  }
}
