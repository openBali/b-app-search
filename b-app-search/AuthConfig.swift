//
//  AuthConfig.swift
//  b-app-search
//

import Foundation

/// 第三方登录凭证。请在各开放平台申请后替换占位符，并同步更新 `Info.plist` 中的 URL Scheme。
enum AuthConfig {
    /// Google Cloud Console → 凭据 → iOS OAuth 客户端 ID
    static let googleClientID = "1041321590753-hcu127j0e53lc9t60ooo40du64q14vcl.apps.googleusercontent.com"

    /// 微信开放平台 → 移动应用 AppID
    static let weChatAppID = "REPLACE_WITH_WECHAT_APP_ID"

    /// 微信开放平台配置的 Universal Link（须与 Associated Domains 一致）
    static let weChatUniversalLink = "https://yourdomain.com/wechat/"

    /// 支付宝开放平台 → 移动应用 AppID
    static let alipayAppID = "REPLACE_WITH_ALIPAY_APP_ID"

    /// 支付宝回跳 URL Scheme（须与 Info.plist CFBundleURLSchemes、开放平台配置一致）
    static let alipayURLScheme = "bappsearchalipay"

    static var isGoogleConfigured: Bool {
        !googleClientID.contains("REPLACE_WITH")
    }

    static var isWeChatConfigured: Bool {
        !weChatAppID.contains("REPLACE_WITH")
    }

    static var isAlipayConfigured: Bool {
        !alipayAppID.contains("REPLACE_WITH")
    }

    /// Google 回调 URL Scheme（与 Info.plist 中 CFBundleURLSchemes 一致）
    static var googleURLScheme: String {
        guard googleClientID.hasSuffix(".apps.googleusercontent.com"),
              !googleClientID.contains("REPLACE_WITH") else {
            return "com.googleusercontent.apps.REPLACE"
        }
        let idPart = googleClientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(idPart)"
    }

    /// 微信回调 URL Scheme：`wx` + AppID
    static var weChatURLScheme: String {
        "wx\(weChatAppID)"
    }
}
