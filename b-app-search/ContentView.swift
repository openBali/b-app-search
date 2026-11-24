//
//  ContentView.swift
//  b-app-search
//
//  Created by Danis on 2026/5/6.
//

import SwiftUI
import UIKit

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
    // 只挂胶囊固有尺寸；左右边由浮钮内部 offset 处理，避免全屏吞点击
    .overlay(alignment: .trailing) {
      FloatingShortcutOverlay(
        onOpenHomeTab: { selectedTab = 0 },
        onOpenMapTab: { selectedTab = 1 }
      )
      // 允许半隐时略微画出安全区，避免被裁成“消失”
      .ignoresSafeArea(edges: .trailing)
    }
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
            // 搜索 → Hero 广告轮播 → 活动提示 → 瀑布流
            HomeAdCarouselView(
              placements: homeAdStore.placements,
              isLoading: homeAdStore.isLoading
            )
            .padding(.horizontal, homeHorizontalPadding)
            .padding(.bottom, 10)

            HomeActivityTipBanner()
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
      .activityRewardToast()
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
          groupSimilarImages: true,
          onImageTap: { image in
            selectedMediaDestination = .open(image, in: sharedImages)
            if let index = sharedImages.firstIndex(where: { $0.id == image.id }) {
              sharedSelectedIndex = index
            }
          },
          onSimilarGroupTap: { group in
            // 堆叠组点击后，按组内顺序一张张浏览
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
      .environmentObject(ActivityStore.shared)
  }
}
