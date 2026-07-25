//
//  ContentView.swift
//  b-app-search
//
//  Created by Danis on 2026/5/6.
//

import CoreLocation
import SwiftUI

struct ContentView: View {
  @Environment(\.appSkin) private var appSkin
  @StateObject private var mapFocus = MapFocusController()
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      HomeView(onOpenMapForImage: openMapForImage)
        .tabItem {
          Label("首页", systemImage: "house.fill")
        }
        .tag(0)

      MapView()
        .tabItem {
          Label("地图", systemImage: "map.fill")
        }
        .tag(1)

      SettingsView()
        .tabItem {
          Label("设置", systemImage: "gearshape.fill")
        }
        .tag(2)
    }
    .tint(appSkin.tokens.accent)
    .environmentObject(mapFocus)
  }

  private func openMapForImage(_ image: GalleryImage) {
    mapFocus.focus(on: image)
    selectedTab = 1
  }
}

private struct HomeView: View {
  let onOpenMapForImage: (GalleryImage) -> Void

  @Environment(\.appSkin) private var appSkin
  @EnvironmentObject private var galleryStore: GalleryStore
  @EnvironmentObject private var tagStore: ImageTagStore
  @EnvironmentObject private var engagementStore: ImageEngagementStore
  @EnvironmentObject private var homeAdStore: HomeAdStore

  @State private var isSearchActive = false
  @State private var searchText = ""
  @FocusState private var isSearchFocused: Bool
  @State private var sharedSelectedIndex = 0
  @State private var selectedMediaDestination: GalleryMediaOpenDestination?
  @State private var showSelfiePage = false

  private let homeHorizontalPadding: CGFloat = 20

  private var sharedImages: [GalleryImage] {
    galleryStore.publicImages
  }

  private var selfieTint: Color { appSkin.tokens.selfieTint }
  private var networkTint: Color { appSkin.tokens.networkTint }

  private var homeMileageKilometers: Double {
    HomeStatsMetrics.mileageKilometers(for: sharedImages)
  }

  private var homeShareCount: Int {
    sharedImages.count
  }

  private var homeLikeCount: Int {
    sharedImages.reduce(0) { $0 + engagementStore.likeCount(for: $1.engagementKey) }
  }

  private var homeSearchHeader: some View {
    HStack(spacing: 10) {
      if isSearchActive {
        Button(action: dismissSearch) {
          Image(systemName: "chevron.left")
            .font(.body.weight(.semibold))
            .foregroundStyle(appSkin.tokens.primaryText ?? Color.primary)
            .frame(width: 36, height: 36)
            .background(appSkin.tokens.cardBackground, in: Circle())
            .overlay {
              Circle().strokeBorder(appSkin.tokens.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("返回首页")
        .transition(.move(edge: .leading).combined(with: .opacity))
      }

      Group {
        if isSearchActive {
          HomeSearchInputBar(searchText: $searchText, isFocused: $isSearchFocused)
        } else {
          HomeSearchBar(onActivate: activateSearch)
        }
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.horizontal, homeHorizontalPadding)
    .padding(.top, 8)
    .padding(.bottom, isSearchActive ? 12 : 10)
  }

  private func activateSearch() {
    withAnimation(.easeInOut(duration: 0.2)) {
      isSearchActive = true
    }
    DispatchQueue.main.async {
      isSearchFocused = true
    }
  }

  private func dismissSearch() {
    isSearchFocused = false
    withAnimation(.easeInOut(duration: 0.2)) {
      isSearchActive = false
      searchText = ""
    }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        LinearGradient(
          colors: [
            Color(.systemBackground),
            Color(.secondarySystemBackground)
          ],
          startPoint: .top,
          endPoint: .bottom
        )
        .ignoresSafeArea()

        VStack(spacing: 0) {
          homeSearchHeader

          if isSearchActive {
            HomeInlineSearchContent(
              searchText: $searchText,
              isSearchFocused: $isSearchFocused,
              horizontalInset: homeHorizontalPadding,
              onLocationTap: { image in
                dismissSearch()
                onOpenMapForImage(image)
              }
            )
            .transition(.opacity)
          } else {
            // 搜索 → 统计 → 广告轮播(第一张为皮肤 Hero) → 内容流
            HomeStatsBar(
              mileageKilometers: homeMileageKilometers,
              shareCount: homeShareCount,
              likeCount: homeLikeCount
            )
            .padding(.horizontal, homeHorizontalPadding)
            .padding(.bottom, 8)

            HomeAdCarouselView(
              placements: homeAdStore.placements,
              isLoading: homeAdStore.isLoading
            )
            .padding(.horizontal, homeHorizontalPadding)
            .padding(.bottom, 8)

            ScrollView {
              VStack(alignment: .leading, spacing: 10) {
                HStack {
                  Spacer(minLength: 0)
                  selfieNetworkEntry
                }

                networkFeedSection
              }
              .padding(.horizontal, homeHorizontalPadding)
              .padding(.bottom, 28)
            }
            .transition(.opacity)
          }
        }
        .animation(.easeInOut(duration: 0.2), value: isSearchActive)
      }
      .navigationBarHidden(true)
      .onAppear {
        syncSharedIndex()
        Task { await homeAdStore.fetchPlacements() }
      }
      .onChange(of: sharedImages.map(\.engagementKey)) { _ in
        syncSharedIndex()
      }
      .fullScreenCover(item: $selectedMediaDestination) { destination in
        GalleryMediaDestinationView(
          destination: destination,
          onLocationTap: { tapped in
            selectedMediaDestination = nil
            onOpenMapForImage(tapped)
          },
          onCurrentImageChanged: { current in
            if let index = sharedImages.firstIndex(where: { $0.id == current.id }) {
              sharedSelectedIndex = index
            }
          }
        )
      }
      .navigationDestination(isPresented: $showSelfiePage) {
        HomeSelfieView(onOpenMapForImage: onOpenMapForImage)
          .environmentObject(galleryStore)
          .environmentObject(tagStore)
      }
    }
  }

  private var selfieNetworkEntry: some View {
    Button {
      showSelfiePage = true
    } label: {
      HStack(spacing: 5) {
        Image(systemName: "person.crop.square.fill")
          .font(.caption)
        Text("selfies")
          .font(.caption.weight(.semibold))
        Image(systemName: "chevron.right")
          .font(.caption2.weight(.bold))
      }
      .foregroundStyle(selfieTint)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(selfieTint.opacity(0.1), in: Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("selfies")
  }

  private var networkFeedSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      if sharedImages.isEmpty {
        emptySharedState
      } else {
        GalleryWaterfallView(
          images: sharedImages,
          horizontalInset: 0,
          onImageTap: { image in
            selectedMediaDestination = .open(image, in: sharedImages)
            if let index = sharedImages.firstIndex(where: { $0.id == image.id }) {
              sharedSelectedIndex = index
            }
          },
          onSimilarGroupTap: { group in
            guard let cover = group.first else { return }
            selectedMediaDestination = .open(cover, in: group)
            if let index = sharedImages.firstIndex(where: { $0.id == cover.id }) {
              sharedSelectedIndex = index
            }
          },
          onLocationTap: onOpenMapForImage
        )
      }
    }
  }

  private var emptySharedState: some View {
    VStack(spacing: 8) {
      Image(systemName: "photo.on.rectangle.angled")
        .font(.title2)
        .foregroundStyle(.secondary)
      Text("暂无已分享图片")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Text("可在 selfies 中添加并发布")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
  }

  private func syncSharedIndex() {
    guard !sharedImages.isEmpty else {
      sharedSelectedIndex = 0
      return
    }
    if sharedSelectedIndex >= sharedImages.count {
      sharedSelectedIndex = sharedImages.count - 1
    }
  }
}

// MARK: - Home stats

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

private struct HomeStatsBar: View {
  let mileageKilometers: Double
  let shareCount: Int
  let likeCount: Int

  @Environment(\.appSkin) private var appSkin

  private var tokens: AppSkinTokens { appSkin.tokens }
  private var primaryText: Color { tokens.primaryText ?? Color.primary }
  private var secondaryText: Color { tokens.secondaryText ?? Color.secondary }

  var body: some View {
    let mileage = HomeStatsMetrics.mileageParts(mileageKilometers)

    HStack(spacing: 0) {
      HomeStatItem(
        icon: "map.fill",
        title: "里程",
        value: mileage.value,
        unit: mileage.unit,
        primaryText: primaryText,
        secondaryText: secondaryText,
        accent: tokens.accent,
        accessibilityLabel: "里程 \(mileage.value)\(mileage.unit)"
      )
      divider
      HomeStatItem(
        icon: "square.and.arrow.up",
        title: "分享",
        value: HomeEngagementFormatting.formatCount(shareCount),
        unit: "次",
        primaryText: primaryText,
        secondaryText: secondaryText,
        accent: tokens.accent,
        accessibilityLabel: "分享 \(shareCount)次"
      )
      divider
      HomeStatItem(
        icon: "heart.fill",
        title: "点赞",
        value: HomeEngagementFormatting.formatCount(likeCount),
        unit: "次",
        primaryText: primaryText,
        secondaryText: secondaryText,
        accent: tokens.accent,
        accessibilityLabel: "点赞 \(likeCount)次"
      )
    }
    .padding(.vertical, 18)
    .padding(.horizontal, 8)
    .frame(minHeight: 96)
    .background(
      tokens.cardBackground,
      in: RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous)
        .strokeBorder(tokens.stroke, lineWidth: 1)
    }
  }

  private var divider: some View {
    Rectangle()
      .fill(tokens.stroke)
      .frame(width: 1, height: 56)
  }
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

struct HomePanelSection<Content: View, Middle: View, Trailing: View>: View {
  let title: String
  let tint: Color
  @ViewBuilder let content: () -> Content
  @ViewBuilder let middle: () -> Middle
  @ViewBuilder let trailing: () -> Trailing

  private let cornerRadius: CGFloat = 16
  private let contentPadding: CGFloat = 16

  init(
    title: String,
    tint: Color,
    @ViewBuilder content: @escaping () -> Content,
    @ViewBuilder middle: @escaping () -> Middle,
    @ViewBuilder trailing: @escaping () -> Trailing
  ) {
    self.title = title
    self.tint = tint
    self.content = content
    self.middle = middle
    self.trailing = trailing
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 8) {
        Text(title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(tint)

        middle()

        Spacer(minLength: 8)

        trailing()
      }

      content()
    }
    .padding(contentPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
  }
}

extension HomePanelSection where Middle == EmptyView {
  init(
    title: String,
    tint: Color,
    @ViewBuilder content: @escaping () -> Content,
    @ViewBuilder trailing: @escaping () -> Trailing
  ) {
    self.title = title
    self.tint = tint
    self.content = content
    self.middle = { EmptyView() }
    self.trailing = trailing
  }
}

extension HomePanelSection where Trailing == EmptyView, Middle == EmptyView {
  init(
    title: String,
    tint: Color,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.title = title
    self.tint = tint
    self.content = content
    self.middle = { EmptyView() }
    self.trailing = { EmptyView() }
  }
}

enum HomeNetworkDisplayMode {
  case network
  case waterfall
}

enum HomeExpandedImageContext: Identifiable {
  case shared(GalleryImage, images: [GalleryImage])
  case `private`(GalleryImage, images: [GalleryImage])

  var id: Int { image.id }

  var image: GalleryImage {
    switch self {
    case .shared(let image, _), .private(let image, _): return image
    }
  }

  var images: [GalleryImage] {
    switch self {
    case .shared(_, let images), .private(_, let images): return images
    }
  }

  func updateIndex(for current: GalleryImage, sharedIndex: inout Int, privateIndex: inout Int) {
    switch self {
    case .shared(_, let images):
      if let index = images.firstIndex(where: { $0.id == current.id }) {
        sharedIndex = index
      }
    case .private(_, let images):
      if let index = images.firstIndex(where: { $0.id == current.id }) {
        privateIndex = index
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .environmentObject(GalleryStore.shared)
      .environmentObject(ImageEngagementStore.shared)
      .environmentObject(ImageTagStore.shared)
      .environmentObject(HomeAdStore.shared)
  }
}
