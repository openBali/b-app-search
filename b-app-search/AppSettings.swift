//
//  AppSettings.swift
//  b-app-search
//

import Foundation
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
  case system
  case light
  case dark

  var id: String { rawValue }

  var title: String {
    switch self {
    case .system: return "跟随系统"
    case .light: return "浅色"
    case .dark: return "深色"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }
}

enum AppLanguage: String, CaseIterable, Identifiable {
  case system
  case zhHans = "zh-Hans"
  case en = "en"
  case ja = "ja"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .system: return "跟随系统"
    case .zhHans: return "简体中文"
    case .en: return "English"
    case .ja: return "日本語"
    }
  }
}

enum PreferredMapApp: String, CaseIterable, Identifiable {
  case apple
  case google
  case amap

  var id: String { rawValue }

  var title: String {
    switch self {
    case .apple: return "Apple 地图"
    case .google: return "Google 地图"
    case .amap: return "高德地图"
    }
  }

  /// 设置中的首选地图排在第一位，其余保持 CaseIterable 默认顺序。
  static func options(preferred: PreferredMapApp) -> [PreferredMapApp] {
    [preferred] + allCases.filter { $0 != preferred }
  }
}

/// 会员档位：默认普通会员；充值成功后自动变为高级会员。
enum MembershipTier: String, CaseIterable, Identifiable {
  case regular
  case premium

  var id: String { rawValue }

  var title: String {
    switch self {
    case .regular: return "普通会员"
    case .premium: return "高级会员"
    }
  }

  var isPremium: Bool { self == .premium }

  static var `default`: MembershipTier { .regular }
}

/// 充值方案；任选其一成功后都会升级为高级会员。
enum MembershipPlan: String, CaseIterable, Identifiable {
  case monthly
  case yearly

  var id: String { rawValue }

  var title: String {
    switch self {
    case .monthly: return "包月"
    case .yearly: return "包年"
    }
  }
}

enum AppSettings {
  /// 首次安装闪屏是否已完成；卸载重装后会再次显示。
  static let hasCompletedSplashKey = "hasCompletedSplash"
  static let membershipTierKey = "membershipTier"
  static let membershipPlanKey = "membershipPlan"

  static let iosPhotoLibrarySyncEnabledKey = "iosPhotoLibrarySyncEnabled"
  static let iosPhotoLibrarySyncActiveKey = "iosPhotoLibrarySyncActive"
  static let shareLocationOnProfileKey = "shareLocationOnProfile"
  static let profileLocationNameKey = "profileLocationName"

  static let showEmailOnProfileKey = "showEmailOnProfile"
  static let showPhoneOnProfileKey = "showPhoneOnProfile"
  static let showAgeOnProfileKey = "showAgeOnProfile"

  static let appearanceKey = "appAppearance"
  static let skinKey = "appSkin"
  static let languageKey = "appLanguage"
  static let preferredMapAppKey = "preferredMapApp"

  static let pushNotificationsEnabledKey = "pushNotificationsEnabled"
  static let notifyCommentsKey = "notifyComments"
  static let notifyLikesKey = "notifyLikes"
  static let notifyFollowsKey = "notifyFollows"
  static let notifySharesKey = "notifyShares"

  static let faceIDEnabledKey = AppSecurityService.faceIDEnabledKey
  static let passcodeEnabledKey = AppSecurityService.passcodeEnabledKey

  static var isPasscodeEnabled: Bool {
    AppSecurityService.isPasscodeEnabled
  }

  static var isFaceIDEnabled: Bool {
    AppSecurityService.isFaceIDEnabled
  }

  static var isIOSPhotoLibrarySyncEnabled: Bool {
    UserDefaults.standard.bool(forKey: iosPhotoLibrarySyncEnabledKey)
  }

  static var isIOSPhotoLibrarySyncActive: Bool {
    UserDefaults.standard.bool(forKey: iosPhotoLibrarySyncActiveKey)
  }

  static var appearance: AppAppearance {
    AppAppearance(rawValue: UserDefaults.standard.string(forKey: appearanceKey) ?? "") ?? .system
  }

  static var skin: AppSkin {
    AppSkin(rawValue: UserDefaults.standard.string(forKey: skinKey) ?? "") ?? .default
  }

  static var membershipTier: MembershipTier {
    MembershipTier(rawValue: UserDefaults.standard.string(forKey: membershipTierKey) ?? "") ?? .default
  }

  static var membershipPlan: MembershipPlan? {
    MembershipPlan(rawValue: UserDefaults.standard.string(forKey: membershipPlanKey) ?? "")
  }

  static func setMembershipTier(_ tier: MembershipTier) {
    UserDefaults.standard.set(tier.rawValue, forKey: membershipTierKey)
  }

  /// 充值成功后调用：记录方案并自动升级为高级会员。
  static func activateMembership(plan: MembershipPlan) {
    UserDefaults.standard.set(plan.rawValue, forKey: membershipPlanKey)
    setMembershipTier(.premium)
  }

  static var language: AppLanguage {
    AppLanguage(rawValue: UserDefaults.standard.string(forKey: languageKey) ?? "") ?? .system
  }

  static var preferredMapApp: PreferredMapApp {
    PreferredMapApp(rawValue: UserDefaults.standard.string(forKey: preferredMapAppKey) ?? "") ?? .apple
  }

  static func setIOSPhotoLibrarySyncEnabled(_ enabled: Bool) {
    UserDefaults.standard.set(enabled, forKey: iosPhotoLibrarySyncEnabledKey)
    if !enabled {
      setIOSPhotoLibrarySyncActive(false)
    }
  }

  static func setIOSPhotoLibrarySyncActive(_ active: Bool) {
    UserDefaults.standard.set(active, forKey: iosPhotoLibrarySyncActiveKey)
  }

  static func setAppearance(_ appearance: AppAppearance) {
    UserDefaults.standard.set(appearance.rawValue, forKey: appearanceKey)
  }

  static func setSkin(_ skin: AppSkin) {
    UserDefaults.standard.set(skin.rawValue, forKey: skinKey)
  }

  static func setLanguage(_ language: AppLanguage) {
    UserDefaults.standard.set(language.rawValue, forKey: languageKey)
  }

  static func setPreferredMapApp(_ mapApp: PreferredMapApp) {
    UserDefaults.standard.set(mapApp.rawValue, forKey: preferredMapAppKey)
  }
}
