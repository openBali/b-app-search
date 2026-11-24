//
//  HomeStatsBar.swift
//  b-app-search
//
//  数据统计条：里程 / 分享 / 点赞 / 评论 / 音乐专辑（个人主页使用）。
//

import CoreLocation
import SwiftUI

enum HomeStatsMetrics {
  static func mileageKilometers(for images: [GalleryImage]) -> Double {
    let located = images
      .filter(\.hasLocation)
      .sorted { lhs, rhs in
        if lhs.id != rhs.id { return lhs.id < rhs.id }
        return lhs.engagementKey < rhs.engagementKey
      }
    guard located.count >= 2 else { return 0 }

    var totalMeters: CLLocationDistance = 0
    for index in 1..<located.count {
      let previous = located[index - 1]
      let current = located[index]
      let from = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
      let to = CLLocation(latitude: current.latitude, longitude: current.longitude)
      totalMeters += from.distance(from: to)
    }
    return totalMeters / 1_000
  }

  static func formatMileage(_ kilometers: Double) -> String {
    let parts = mileageParts(kilometers)
    if parts.unit == "米" { return "\(parts.value)m" }
    return parts.value
  }

  static func mileageParts(_ kilometers: Double) -> (value: String, unit: String) {
    if kilometers <= 0 { return ("0", "公里") }
    if kilometers < 1 {
      return ("\(Int((kilometers * 1_000).rounded()))", "米")
    }
    if kilometers < 10 {
      return (String(format: "%.1f", kilometers), "公里")
    }
    if kilometers < 1_000 {
      return (String(format: "%.0f", kilometers.rounded()), "公里")
    }
    return (HomeEngagementFormatting.formatCount(Int(kilometers.rounded())), "公里")
  }
}

struct HomeStatsBar: View {
  let mileageKilometers: Double
  let shareCount: Int
  let likeCount: Int
  let commentCount: Int
  let musicAlbumCount: Int

  @Environment(\.appSkin) private var appSkin
  /// 用本地 State 保证点击立刻响应；AppStorage 仅作持久化。
  @State private var isCollapsed = UserDefaults.standard.object(forKey: AppSettings.homeStatsCollapsedKey) as? Bool ?? true

  private var tokens: AppSkinTokens { appSkin.tokens }
  private var primaryText: Color { tokens.primaryText ?? Color.primary }
  private var secondaryText: Color { tokens.secondaryText ?? Color.secondary }

  /// 一屏约显示 3 项，其余横向滑看。
  private let visibleItemCount: CGFloat = 3

  private var statItems: [HomeStatDisplayItem] {
    let mileage = HomeStatsMetrics.mileageParts(mileageKilometers)
    return [
      HomeStatDisplayItem(
        id: "mileage",
        icon: "map.fill",
        title: "里程",
        value: mileage.value,
        unit: mileage.unit,
        accessibilityLabel: "里程 \(mileage.value)\(mileage.unit)"
      ),
      HomeStatDisplayItem(
        id: "share",
        icon: "square.and.arrow.up",
        title: "分享",
        value: HomeEngagementFormatting.formatCount(shareCount),
        unit: "次",
        accessibilityLabel: "分享 \(shareCount)次"
      ),
      HomeStatDisplayItem(
        id: "like",
        icon: "heart.fill",
        title: "点赞",
        value: HomeEngagementFormatting.formatCount(likeCount),
        unit: "次",
        accessibilityLabel: "点赞 \(likeCount)次"
      ),
      HomeStatDisplayItem(
        id: "comment",
        icon: "bubble.left.and.bubble.right.fill",
        title: "评论",
        value: HomeEngagementFormatting.formatCount(commentCount),
        unit: "条",
        accessibilityLabel: "评论 \(commentCount)条"
      ),
      HomeStatDisplayItem(
        id: "music",
        icon: "music.note.list",
        title: "音乐专辑",
        value: HomeEngagementFormatting.formatCount(musicAlbumCount),
        unit: "张",
        accessibilityLabel: "音乐专辑 \(musicAlbumCount)张"
      )
    ]
  }

  var body: some View {
    VStack(spacing: 0) {
      headerRow

      if !isCollapsed {
        Divider().opacity(0.5)

        GeometryReader { geo in
          let horizontalPadding: CGFloat = 8
          let itemWidth = max((geo.size.width - horizontalPadding * 2) / visibleItemCount, 96)

          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
              ForEach(Array(statItems.enumerated()), id: \.element.id) { index, item in
                HomeStatItem(
                  icon: item.icon,
                  title: item.title,
                  value: item.value,
                  unit: item.unit,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  accent: tokens.accent,
                  accessibilityLabel: item.accessibilityLabel
                )
                .frame(width: itemWidth)

                if index < statItems.count - 1 {
                  Rectangle()
                    .fill(tokens.stroke)
                    .frame(width: 1, height: 56)
                }
              }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 12)
          }
        }
        .frame(height: 108)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .background(
      tokens.cardBackground,
      in: RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous)
        .strokeBorder(tokens.stroke, lineWidth: 1)
    }
    .animation(.easeInOut(duration: 0.22), value: isCollapsed)
  }

  private var headerRow: some View {
    HStack(spacing: 10) {
      Image(systemName: "chart.bar.fill")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(tokens.accent)
        .frame(width: 28, height: 28)
        .background(tokens.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

      VStack(alignment: .leading, spacing: 2) {
        Text("数据统计")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(primaryText)

        if isCollapsed {
          Text(collapsedSummary)
            .font(.caption2)
            .foregroundStyle(secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        } else {
          Text("左右滑动查看更多指标")
            .font(.caption2)
            .foregroundStyle(secondaryText)
        }
      }

      Spacer(minLength: 8)

      Image(systemName: "chevron.down")
        .font(.caption.weight(.bold))
        .foregroundStyle(secondaryText)
        .rotationEffect(.degrees(isCollapsed ? 0 : 180))
        .frame(width: 28, height: 28)
        .background(tokens.stroke.opacity(0.28), in: Circle())
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .contentShape(Rectangle())
    .onTapGesture(perform: toggleCollapsed)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(isCollapsed ? "展开数据统计" : "收起数据统计")
    .accessibilityValue(collapsedSummary)
    .accessibilityAddTraits(.isButton)
  }

  private var collapsedSummary: String {
    let mileage = HomeStatsMetrics.mileageParts(mileageKilometers)
    let mileageText = mileage.unit == "米"
      ? "\(mileage.value)m"
      : "\(mileage.value)\(mileage.unit == "公里" ? "km" : mileage.unit)"
    return "\(mileageText) · 分享\(HomeEngagementFormatting.formatCount(shareCount)) · 赞\(HomeEngagementFormatting.formatCount(likeCount)) · 评\(HomeEngagementFormatting.formatCount(commentCount)) · 乐\(HomeEngagementFormatting.formatCount(musicAlbumCount))"
  }

  private func toggleCollapsed() {
    let next = !isCollapsed
    withAnimation(.easeInOut(duration: 0.22)) {
      isCollapsed = next
    }
    UserDefaults.standard.set(next, forKey: AppSettings.homeStatsCollapsedKey)
  }
}

private struct HomeStatDisplayItem: Identifiable {
  let id: String
  let icon: String
  let title: String
  let value: String
  let unit: String
  let accessibilityLabel: String
}

private struct HomeStatItem: View {
  let icon: String
  let title: String
  let value: String
  let unit: String
  let primaryText: Color
  let secondaryText: Color
  let accent: Color
  let accessibilityLabel: String

  var body: some View {
    VStack(spacing: 6) {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .font(.caption.weight(.semibold))
          .foregroundStyle(accent)
        Text(title)
          .font(.caption.weight(.medium))
          .foregroundStyle(secondaryText)
      }

      Text(value)
        .font(.title3.weight(.bold).monospacedDigit())
        .foregroundStyle(primaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.75)

      Text(unit)
        .font(.caption2)
        .foregroundStyle(secondaryText)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }
}
