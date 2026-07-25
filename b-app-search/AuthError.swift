//
//  AuthError.swift
//  b-app-search
//

import Foundation

enum AuthError: LocalizedError {
    case notConfigured(String)
    case weChatNotInstalled
    case weChatFailed(String?)
    case alipayNotInstalled
    case alipayFailed(String?)
    case cancelled
    case noPresenter
    case appleFailed(String?)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let provider):
            return "请先在 AuthConfig.swift 与 Info.plist 中配置 \(provider) 的 App ID / Client ID。"
        case .weChatNotInstalled:
            return "未安装微信，请先安装微信客户端。"
        case .weChatFailed(let message):
            return message ?? "微信授权失败，请重试。"
        case .alipayNotInstalled:
            return "未安装支付宝，请先安装支付宝客户端。"
        case .alipayFailed(let message):
            return message ?? "支付宝授权失败，请重试。"
        case .cancelled:
            return "已取消登录。"
        case .noPresenter:
            return "无法打开登录界面，请稍后重试。"
        case .appleFailed(let message):
            return message ?? "Apple 登录失败，请重试。"
        }
    }
}
