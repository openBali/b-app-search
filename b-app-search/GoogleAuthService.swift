//
//  GoogleAuthService.swift
//  b-app-search
//

import GoogleSignIn
import UIKit

@MainActor
final class GoogleAuthService {
    static let shared = GoogleAuthService()

    private init() {}

    func configure() {
        guard AuthConfig.isGoogleConfigured else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: AuthConfig.googleClientID)
    }

    func restorePreviousSignIn(completion: @escaping (Bool) -> Void) {
        guard AuthConfig.isGoogleConfigured else {
            completion(false)
            return
        }
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let user, error == nil {
                let nickname = user.profile?.name ?? user.profile?.email ?? "Google 用户"
                UserSession.signIn(nickname: nickname, email: user.profile?.email)
                completion(true)
            } else {
                completion(false)
            }
        }
    }

    func signIn() async throws -> GIDGoogleUser {
        guard AuthConfig.isGoogleConfigured else {
            throw AuthError.notConfigured("Google")
        }
        guard let presenter = UIApplication.shared.topViewController else {
            throw AuthError.noPresenter
        }

        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let user = result?.user else {
                    continuation.resume(throwing: AuthError.cancelled)
                    return
                }
                continuation.resume(returning: user)
            }
        }
    }

    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}
