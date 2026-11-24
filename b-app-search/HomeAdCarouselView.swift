//
//  HomeAdCarouselView.swift
//  b-app-search
//
//  首页广告推荐位：第一张为皮肤 Hero，其后为运营广告卡。
//

import SwiftUI

struct HomeAdCarouselView: View {
  let placements: [HomeAdPlacement]
  var isLoading: Bool = false

  @Environment(\.appSkin) private var appSkin

  @State private var currentIndex = 0
  // @State private var isHovering = false
  // @State private var isTouchRevealed = false
  // @State private var hideControlsTask: Task<Void, Never>?

  private let cardHeight: CGFloat = 188
  private let heroHeight: CGFloat = 96

  private var pages: [HomeAdCarouselPage] {
    [.skinHero] + placements.map { .ad($0) }
  }

  /*
  private var showsPageControls: Bool {
    pages.count > 1 && (isHovering || isTouchRevealed)
  }
  */

  var body: some View {
    ZStack(alignment: .top) {
      TabView(selection: $currentIndex) {
        ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
          carouselPage(page)
            .tag(index)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .frame(height: cardHeight)

      /*
      if pages.count > 1 {
        pageArrowOverlay
          .frame(height: heroHeight)
          .opacity(showsPageControls ? 1 : 0)
          .allowsHitTesting(showsPageControls)
          .animation(.easeInOut(duration: 0.18), value: showsPageControls)
      }

      if isLoading, placements.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
          .padding(.bottom, 18)
          .allowsHitTesting(false)
      }
      */
    }
    /*
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.18)) {
        isHovering = hovering
      }
      if hovering {
        cancelHideControlsTask()
      }
    }
    .simultaneousGesture(
      TapGesture().onEnded {
        guard pages.count > 1 else { return }
        revealControlsTemporarily()
      }
    )
    */
    .onChange(of: pages.count) { newCount in
      if currentIndex >= newCount {
        currentIndex = max(newCount - 1, 0)
      }
    }
    .onChange(of: appSkin.rawValue) { _ in
      currentIndex = 0
    }
    .onAppear {
      _ = isLoading
    }
  }

  @ViewBuilder
  private func carouselPage(_ page: HomeAdCarouselPage) -> some View {
    switch page {
    case .skinHero:
      HomeSkinHeroCard(heroHeight: heroHeight)
        .id(appSkin.rawValue)
    case .ad(let placement):
      HomeAdPlacementCard(placement: placement, heroHeight: heroHeight)
    }
  }

  /*
  private var pageArrowOverlay: some View {
    HStack {
      pageArrowButton(systemName: "chevron.left", accessibilityLabel: "上一页") {
        goToPreviousPage()
      }

      Spacer()

      pageArrowButton(systemName: "chevron.right", accessibilityLabel: "下一页") {
        goToNextPage()
      }
    }
    .padding(.horizontal, 10)
  }

  private func pageArrowButton(
    systemName: String,
    accessibilityLabel: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 30, height: 30)
        .background(.black.opacity(0.42), in: Circle())
        .overlay {
          Circle().strokeBorder(.white.opacity(0.28), lineWidth: 0.5)
        }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
  }

  private func goToPreviousPage() {
    guard !pages.isEmpty else { return }
    withAnimation(.easeInOut(duration: 0.25)) {
      currentIndex = (currentIndex - 1 + pages.count) % pages.count
    }
    revealControlsTemporarily()
  }

  private func goToNextPage() {
    guard !pages.isEmpty else { return }
    withAnimation(.easeInOut(duration: 0.25)) {
      currentIndex = (currentIndex + 1) % pages.count
    }
    revealControlsTemporarily()
  }

  private func revealControlsTemporarily() {
    withAnimation(.easeInOut(duration: 0.18)) {
      isTouchRevealed = true
    }
    cancelHideControlsTask()
    hideControlsTask = Task {
      try? await Task.sleep(nanoseconds: 2_500_000_000)
      guard !Task.isCancelled else { return }
      await MainActor.run {
        withAnimation(.easeInOut(duration: 0.18)) {
          isTouchRevealed = false
        }
      }
    }
  }

  private func cancelHideControlsTask() {
    hideControlsTask?.cancel()
    hideControlsTask = nil
  }
  */
}

private enum HomeAdCarouselPage: Identifiable, Hashable {
  case skinHero
  case ad(HomeAdPlacement)

  var id: String {
    switch self {
    case .skinHero: return "skin-hero"
    case .ad(let placement): return placement.id
    }
  }
}

/// 皮肤 Hero：仅保留图片 + 白色大标题。
private struct HomeSkinHeroCard: View {
  let heroHeight: CGFloat

  @Environment(\.appSkin) private var appSkin

  // private var tokens: AppSkinTokens { appSkin.tokens }

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      Image(skinAsset: .homeHero, skin: appSkin)
        .resizable()
        .scaledToFill()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()

      // 底部轻微遮罩，保证白字可读
      LinearGradient(
        colors: [.clear, .black.opacity(0.45)],
        startPoint: .center,
        endPoint: .bottom
      )
      .allowsHitTesting(false)

      Text(appSkin.title)
        .font(.largeTitle.weight(.bold))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipShape(RoundedRectangle(cornerRadius: appSkin.tokens.cardCornerRadius, style: .continuous))
    .accessibilityLabel(appSkin.title)

    /*
    VStack(alignment: .leading, spacing: 0) {
      Image(skinAsset: .homeHero, skin: appSkin)
        .resizable()
        .scaledToFill()
        .frame(height: heroHeight)
        .frame(maxWidth: .infinity)
        .clipped()

      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .center, spacing: 8) {
          Image(systemName: appSkin.systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tokens.accent)
            .frame(width: 28, height: 28)
            .background(tokens.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

          VStack(alignment: .leading, spacing: 2) {
            Text(appSkin.title)
              .font(.caption.weight(.semibold))
              .foregroundStyle(tokens.primaryText ?? Color.primary)
              .lineLimit(1)

            Text(appSkin.subtitle)
              .font(.caption2)
              .foregroundStyle(tokens.secondaryText ?? Color.secondary)
              .lineLimit(1)
          }
        }

        HStack(spacing: 6) {
          Text("主题")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tokens.accent, in: Capsule())

          Text("当前皮肤 · \(appSkin.title)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tokens.primaryText ?? Color.primary)
            .lineLimit(1)
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
    }
    .background(tokens.cardBackground, in: RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous)
        .strokeBorder(tokens.stroke, lineWidth: 1)
    }
    .clipShape(RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous))
    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("主题 \(appSkin.title)，\(appSkin.subtitle)")
    */
  }
}

private struct HomeAdPlacementCard: View {
  let placement: HomeAdPlacement
  let heroHeight: CGFloat

  @Environment(\.appSkin) private var appSkin

  // private var tokens: AppSkinTokens { appSkin.tokens }

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      heroImage
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()

      LinearGradient(
        colors: [.clear, .black.opacity(0.45)],
        startPoint: .center,
        endPoint: .bottom
      )
      .allowsHitTesting(false)

      Text(placement.brandName)
        .font(.largeTitle.weight(.bold))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipShape(RoundedRectangle(cornerRadius: appSkin.tokens.cardCornerRadius, style: .continuous))
    .accessibilityLabel(placement.brandName)

    /*
    VStack(alignment: .leading, spacing: 0) {
      heroImage

      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .center, spacing: 8) {
          brandLogo

          VStack(alignment: .leading, spacing: 2) {
            Text(placement.brandName)
              .font(.caption.weight(.semibold))
              .foregroundStyle(tokens.primaryText ?? Color.primary)
              .lineLimit(1)

            Text(placement.brandIntro)
              .font(.caption2)
              .foregroundStyle(tokens.secondaryText ?? Color.secondary)
              .lineLimit(1)
          }
        }

        hotProductBadge
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
    }
    .background(tokens.cardBackground, in: RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous)
        .strokeBorder(tokens.stroke, lineWidth: 1)
    }
    .clipShape(RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous))
    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(placement.brandName)，\(placement.hotProductCopy)")
    */
  }

  private var heroImage: some View {
    AsyncImage(url: placement.heroImageURL) { phase in
      switch phase {
      case .success(let image):
        image
          .resizable()
          .scaledToFill()
      case .failure:
        heroPlaceholder
      default:
        heroPlaceholder
          .overlay { ProgressView() }
      }
    }
    // .frame(height: heroHeight)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
  }

  private var heroPlaceholder: some View {
    Color(.tertiarySystemFill)
      .overlay {
        Image(systemName: "photo.on.rectangle.angled")
          .font(.title2)
          .foregroundStyle(.secondary)
      }
  }

  /*
  @ViewBuilder
  private var brandLogo: some View {
    if let logoURL = placement.brandLogoURL {
      AsyncImage(url: logoURL) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
        default:
          brandLogoFallback
        }
      }
      .frame(width: 28, height: 28)
      .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .strokeBorder(tokens.stroke, lineWidth: 0.5)
      }
    } else {
      brandLogoFallback
    }
  }

  private var brandLogoFallback: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 7, style: .continuous)
        .fill(UserAvatarView.accentColor(for: placement.brandName))
      Text(String(placement.brandName.prefix(1)))
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
    }
    .frame(width: 28, height: 28)
  }

  private var hotProductBadge: some View {
    HStack(spacing: 6) {
      Text("爆款")
        .font(.caption2.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(tokens.danger, in: Capsule())

      Text(placement.hotProductCopy)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tokens.primaryText ?? Color.primary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
  */
}

struct HomeAdCarouselView_Previews: PreviewProvider {
  static var previews: some View {
    HomeAdCarouselView(placements: HomeAdPlacement.mockPlacements)
      .padding()
      .environment(\.appSkin, .fresh)
  }
}
