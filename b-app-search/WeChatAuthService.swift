//
//  WeChatAuthService.swift
//  b-app-search
//

import Foundation
import UIKit

final class WeChatAuthService: NSObject {
    static let shared = WeChatAuthService()

    private var authContinuation: CheckedContinuation<String, Error>?

    private override init() {
        super.init()
    }

    func configure() {
        guard AuthConfig.isWeChatConfigured else { return }
        DispatchQueue.main.async {
            WXApi.registerApp(AuthConfig.weChatAppID, universalLink: AuthConfig.weChatUniversalLink)
        }
    }

    func signIn() async throws -> String {
        guard AuthConfig.isWeChatConfigured else {
            throw AuthError.notConfigured("微信")
        }
        guard WXApi.isWXAppInstalled() else {
            throw AuthError.weChatNotInstalled
        }

        return try await withCheckedThrowingContinuation { continuation in
            authContinuation = continuation
            let request = SendAuthReq()
            request.scope = "snsapi_userinfo"
            request.state = UUID().uuidString
            WXApi.send(request) { [weak self] success in
                if !success {
                    self?.authContinuation = nil
                    continuation.resume(throwing: AuthError.weChatFailed("无法唤起微信"))
                }
            }
        }
    }

    @discardableResult
    func handleOpenURL(_ url: URL) -> Bool {
        WXApi.handleOpen(url, delegate: self)
    }

    @discardableResult
    func handleUniversalLink(_ userActivity: NSUserActivity) -> Bool {
        WXApi.handleOpenUniversalLink(userActivity, delegate: self)
    }
}

extension WeChatAuthService: WXApiDelegate {
    func onReq(_ req: BaseReq) {}

    func onResp(_ resp: BaseResp) {
        guard let authResp = resp as? SendAuthResp else { return }
        defer { authContinuation = nil }

        if authResp.errCode == 0, let code = authResp.code, !code.isEmpty {
            authContinuation?.resume(returning: code)
        } else if authResp.errCode == -2 {
            authContinuation?.resume(throwing: AuthError.cancelled)
        } else {
            authContinuation?.resume(throwing: AuthError.weChatFailed(authResp.errStr))
        }
    }
}
