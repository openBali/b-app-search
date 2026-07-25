//
//  LoginViewModel.swift
//  b-app-search
//

import AuthenticationServices
import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
  @Published var isLoading = false
  @Published var errorMessage: String?

  private let weChatAuth = WeChatAuthService.shared
  private let alipayAuth = AlipayAuthService.shared

  func signInWithWeChat(onSuccess: @escaping () -> Void) {
    guard !isLoading else { return }
    isLoading = true
    errorMessage = nil

    Task {
      do {
        let code = try await weChatAuth.signIn()
        let session = try await BackendAPI.Auth.exchangeWeChatCode(code)
        UserDefaults.standard.set(code, forKey: "weChatAuthCode")
        BackendAPI.Auth.applySession(session)
        onSuccess()
      } catch {
        if case AuthError.cancelled = error {
          isLoading = false
          return
        }
        errorMessage = error.localizedDescription
      }
      isLoading = false
    }
  }

  func signInWithAlipay(onSuccess: @escaping () -> Void) {
    guard !isLoading else { return }
    isLoading = true
    errorMessage = nil

    Task {
      do {
        let authCode = try await alipayAuth.signIn()
        let session = try await BackendAPI.Auth.exchangeAlipayAuthCode(authCode)
        UserDefaults.standard.set(authCode, forKey: "alipayAuthCode")
        BackendAPI.Auth.applySession(session)
        onSuccess()
      } catch {
        if case AuthError.cancelled = error {
          isLoading = false
          return
        }
        errorMessage = error.localizedDescription
      }
      isLoading = false
    }
  }

  func signInWithApple(onSuccess: @escaping () -> Void) {
    guard !isLoading else { return }
    isLoading = true
    errorMessage = nil

    Task {
      do {
        let payload = try await AppleAuthService.shared.signIn()
        try await completeAppleSignIn(with: payload)
        onSuccess()
      } catch {
        handleAppleError(error)
      }
      isLoading = false
    }
  }

  func handleAppleAuthorization(_ authorization: ASAuthorization, onSuccess: @escaping () -> Void) {
    guard !isLoading else { return }
    isLoading = true
    errorMessage = nil

    Task {
      do {
        let payload = try AppleAuthService.shared.credentialPayload(from: authorization)
        try await completeAppleSignIn(with: payload)
        onSuccess()
      } catch {
        handleAppleError(error)
      }
      isLoading = false
    }
  }

  func handleAppleSignInFailure(_ error: Error) {
    handleAppleError(error)
  }

  private func completeAppleSignIn(with payload: AppleAuthCredentialPayload) async throws {
    let session = try await BackendAPI.Auth.exchangeAppleIdentityToken(
      payload.identityToken,
      userIdentifier: payload.userIdentifier,
      email: payload.email,
      fullName: payload.fullName,
      authorizationCode: payload.authorizationCode
    )
    BackendAPI.Auth.applySession(session, appleUserID: payload.userIdentifier)
  }

  private func handleAppleError(_ error: Error) {
    if case AuthError.cancelled = error {
      return
    }
    let nsError = error as NSError
    if nsError.domain == ASAuthorizationError.errorDomain,
       nsError.code == ASAuthorizationError.canceled.rawValue
    {
      return
    }
    errorMessage = error.localizedDescription
  }

  func signInWithGoogle(onSuccess: @escaping () -> Void) {
    guard !isLoading else { return }
    isLoading = true
    errorMessage = nil

    Task {
      do {
        if AuthConfig.isGoogleConfigured {
          let user = try await GoogleAuthService.shared.signIn()
          let idToken = user.idToken?.tokenString ?? ""
          let session = try await BackendAPI.Auth.exchangeGoogleIDToken(idToken)
          BackendAPI.Auth.applySession(session)
        } else {
          let session = try await BackendAPI.Auth.exchangeGoogleIDToken("")
          BackendAPI.Auth.applySession(session)
        }
        onSuccess()
      } catch {
        errorMessage = error.localizedDescription
      }
      isLoading = false
    }
  }
}
