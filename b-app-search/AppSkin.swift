//
//  AppSkin.swift
//  b-app-search
//
//  皮肤系统：代码 token（类似 CSS 变量）+ 图片资源槽位（按皮肤名解析，缺失则回退）。
//

import SwiftUI
import UIKit

// MARK: - Skin identity

enum AppSkin: String, CaseIterable, Identifiable {
  case fresh
  case dad
  case classical

  var id: String { rawValue }

  var title: String {
    switch self {
    case .fresh: return "清爽"
    case .dad: return "爹味"
    case .classical: return "古典"
    }
  }

  var subtitle: String {
    switch self {
    case .fresh: return "干净冷色，轻盈留白"
    case .dad: return "厚重暖调，稳重可靠"
    case .classical: return "墨色丹砂，纸感纹理"
    }
  }

  var systemImage: String {
    switch self {
    case .fresh: return "leaf.fill"
    case .dad: return "person.fill.checkmark"
    case .classical: return "scroll.fill"
    }
  }

  var tokens: AppSkinTokens {
    switch self {
    case .fresh: return .fresh
    case .dad: return .dad
    case .classical: return .classical
    }
  }

  static var `default`: AppSkin { .fresh }
}

// MARK: - Code-controlled tokens (CSS-like)

struct AppSkinTokens {
  /// 主强调色（按钮、选中态、Tab tint）
  var accent: Color
  /// 次强调色
  var secondaryAccent: Color
  /// 首页「网络」分区 tint
  var networkTint: Color
  /// 首页「自拍」入口 tint
  var selfieTint: Color
  /// 页面大背景（可叠在系统背景之上）
  var canvasBackground: Color
  /// 卡片 / 分组底
  var cardBackground: Color
  /// 分割线 / 描边
  var stroke: Color
  /// 主文字（可选覆盖；nil 表示跟随系统）
  var primaryText: Color?
  /// 次文字
  var secondaryText: Color?
  /// 成功 / 通过
  var success: Color
  /// 警告
  var warning: Color
  /// 危险
  var danger: Color
  /// 大圆角（卡片）
  var cardCornerRadius: CGFloat
  /// 小圆角（胶囊按钮等）
  var chipCornerRadius: CGFloat
  /// 首页英雄区渐变（UIKit 绘制用）
  var heroGradientUIColors: [UIColor]
  /// 设置预览色带
  var previewSwatches: [Color]

  var heroGradient: [Color] {
    heroGradientUIColors.map { Color($0) }
  }

  static let fresh = AppSkinTokens(
    accent: Color(red: 0.22, green: 0.55, blue: 0.98),
    secondaryAccent: Color(red: 0.18, green: 0.78, blue: 0.72),
    networkTint: Color(red: 0.28, green: 0.48, blue: 0.98),
    selfieTint: Color(red: 0.42, green: 0.38, blue: 0.55),
    canvasBackground: Color(.systemGroupedBackground),
    cardBackground: Color(.secondarySystemGroupedBackground),
    stroke: Color.primary.opacity(0.08),
    primaryText: nil,
    secondaryText: nil,
    success: Color(red: 0.20, green: 0.72, blue: 0.45),
    warning: Color(red: 0.95, green: 0.62, blue: 0.12),
    danger: Color(red: 0.95, green: 0.32, blue: 0.38),
    cardCornerRadius: 16,
    chipCornerRadius: 999,
    heroGradientUIColors: [
      UIColor(red: 0.55, green: 0.75, blue: 1.0, alpha: 1),
      UIColor(red: 0.45, green: 0.88, blue: 0.82, alpha: 1),
      UIColor(red: 0.78, green: 0.86, blue: 1.0, alpha: 1),
    ],
    previewSwatches: [
      Color(red: 0.28, green: 0.48, blue: 0.98),
      Color(red: 0.18, green: 0.78, blue: 0.72),
      Color(red: 0.92, green: 0.95, blue: 0.99),
    ]
  )

  static let dad = AppSkinTokens(
    accent: Color(red: 0.72, green: 0.42, blue: 0.16),
    secondaryAccent: Color(red: 0.28, green: 0.38, blue: 0.28),
    networkTint: Color(red: 0.78, green: 0.48, blue: 0.18),
    selfieTint: Color(red: 0.35, green: 0.32, blue: 0.28),
    canvasBackground: Color(red: 0.96, green: 0.93, blue: 0.86),
    cardBackground: Color(red: 0.99, green: 0.97, blue: 0.92),
    stroke: Color(red: 0.55, green: 0.42, blue: 0.28).opacity(0.22),
    primaryText: Color(red: 0.22, green: 0.18, blue: 0.14),
    secondaryText: Color(red: 0.42, green: 0.36, blue: 0.28),
    success: Color(red: 0.32, green: 0.55, blue: 0.30),
    warning: Color(red: 0.88, green: 0.55, blue: 0.12),
    danger: Color(red: 0.78, green: 0.28, blue: 0.18),
    cardCornerRadius: 12,
    chipCornerRadius: 8,
    heroGradientUIColors: [
      UIColor(red: 0.78, green: 0.55, blue: 0.28, alpha: 1),
      UIColor(red: 0.45, green: 0.38, blue: 0.28, alpha: 1),
      UIColor(red: 0.88, green: 0.72, blue: 0.42, alpha: 1),
    ],
    previewSwatches: [
      Color(red: 0.72, green: 0.42, blue: 0.16),
      Color(red: 0.28, green: 0.38, blue: 0.28),
      Color(red: 0.96, green: 0.93, blue: 0.86),
    ]
  )

  static let classical = AppSkinTokens(
    accent: Color(red: 0.72, green: 0.18, blue: 0.16),
    secondaryAccent: Color(red: 0.72, green: 0.58, blue: 0.28),
    networkTint: Color(red: 0.62, green: 0.16, blue: 0.14),
    selfieTint: Color(red: 0.28, green: 0.24, blue: 0.20),
    canvasBackground: Color(red: 0.95, green: 0.92, blue: 0.85),
    cardBackground: Color(red: 0.98, green: 0.96, blue: 0.90),
    stroke: Color(red: 0.35, green: 0.28, blue: 0.20).opacity(0.28),
    primaryText: Color(red: 0.14, green: 0.12, blue: 0.10),
    secondaryText: Color(red: 0.38, green: 0.32, blue: 0.24),
    success: Color(red: 0.28, green: 0.48, blue: 0.32),
    warning: Color(red: 0.78, green: 0.55, blue: 0.18),
    danger: Color(red: 0.72, green: 0.18, blue: 0.16),
    cardCornerRadius: 10,
    chipCornerRadius: 4,
    heroGradientUIColors: [
      UIColor(red: 0.72, green: 0.18, blue: 0.16, alpha: 1),
      UIColor(red: 0.22, green: 0.18, blue: 0.16, alpha: 1),
      UIColor(red: 0.72, green: 0.58, blue: 0.28, alpha: 1),
    ],
    previewSwatches: [
      Color(red: 0.72, green: 0.18, blue: 0.16),
      Color(red: 0.72, green: 0.58, blue: 0.28),
      Color(red: 0.95, green: 0.92, blue: 0.85),
    ]
  )
}

// MARK: - Image slots (resource-driven, like swapping CSS background-image)

/// 需要按皮肤切换的图片槽位。
/// 资源命名：`Skin_{slot}_{skin}`，例如 `Skin_homeHero_fresh`。
/// 解析顺序：皮肤专属 → `Skin_{slot}_shared` → 全局回退名 → 代码生成图。
enum AppSkinImageSlot: String, CaseIterable {
  case homeHero
  case loginHeader
  case captchaBackground
  case settingsBanner

  /// 未找到皮肤图时的全局回退（现有工程资源）
  var legacyFallbackName: String? {
    switch self {
    case .homeHero, .captchaBackground, .loginHeader: return "HomeImage"
    case .settingsBanner: return nil
    }
  }

  func assetName(for skin: AppSkin) -> String {
    "Skin_\(rawValue)_\(skin.rawValue)"
  }

  var sharedAssetName: String {
    "Skin_\(rawValue)_shared"
  }

  func uiImage(for skin: AppSkin, size: CGSize = CGSize(width: 720, height: 336)) -> UIImage {
    if let named = UIImage(named: assetName(for: skin)) {
      return named
    }
    if let shared = UIImage(named: sharedAssetName) {
      return shared
    }
    if let legacy = legacyFallbackName, let image = UIImage(named: legacy) {
      return image
    }
    return AppSkinImageFactory.makePlaceholder(slot: self, skin: skin, size: size)
  }

  func image(for skin: AppSkin) -> Image {
    Image(uiImage: uiImage(for: skin))
  }
}

enum AppSkinImageFactory {
  static func makePlaceholder(slot: AppSkinImageSlot, skin: AppSkin, size: CGSize) -> UIImage {
    let tokens = skin.tokens
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
      let colors = tokens.heroGradientUIColors.map(\.cgColor)
      let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors as CFArray,
        locations: [0, 0.55, 1]
      )!
      context.cgContext.drawLinearGradient(
        gradient,
        start: .zero,
        end: CGPoint(x: size.width, y: size.height),
        options: []
      )

      // 轻纹理，区分皮肤气质
      let speckCount: Int
      switch skin {
      case .fresh: speckCount = 10
      case .dad: speckCount = 28
      case .classical: speckCount = 40
      }
      for _ in 0..<speckCount {
        let x = CGFloat.random(in: 0...size.width)
        let y = CGFloat.random(in: 0...size.height)
        let radius = CGFloat.random(in: 4...22)
        UIColor.white.withAlphaComponent(CGFloat.random(in: 0.05...0.18)).setFill()
        context.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: radius, height: radius))
      }

      let title: String
      switch slot {
      case .homeHero: title = skin.title
      case .loginHeader: title = "登录 · \(skin.title)"
      case .captchaBackground: title = "验证"
      case .settingsBanner: title = "皮肤"
      }
      let paragraph = NSMutableParagraphStyle()
      paragraph.alignment = .center
      let attrs: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: min(size.width, size.height) * 0.12, weight: .semibold),
        .foregroundColor: UIColor.white.withAlphaComponent(0.88),
        .paragraphStyle: paragraph,
      ]
      let rect = CGRect(x: 16, y: (size.height - 36) / 2, width: size.width - 32, height: 40)
      (title as NSString).draw(in: rect, withAttributes: attrs)
    }
  }
}

// MARK: - Environment

private struct AppSkinKey: EnvironmentKey {
  static let defaultValue: AppSkin = .default
}

extension EnvironmentValues {
  var appSkin: AppSkin {
    get { self[AppSkinKey.self] }
    set { self[AppSkinKey.self] = newValue }
  }
}

extension View {
  /// 将皮肤 token 应用到根视图（tint / 画布底色）。
  func applyAppSkin(_ skin: AppSkin) -> some View {
    environment(\.appSkin, skin)
      .tint(skin.tokens.accent)
      .background(skin.tokens.canvasBackground.ignoresSafeArea())
  }
}

extension Image {
  /// 按当前皮肤加载槽位图片（需配合 `.environment(\.appSkin, ...)`）。
  init(skinAsset slot: AppSkinImageSlot, skin: AppSkin) {
    self.init(uiImage: slot.uiImage(for: skin))
  }
}
