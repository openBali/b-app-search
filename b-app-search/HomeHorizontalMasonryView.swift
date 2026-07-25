//
//  HomeHorizontalMasonryView.swift
//  b-app-search
//
//  首页单行横向瀑布流：固定一行高度，图片宽度错落，左右滑动浏览。
//

import SwiftUI

enum HomeMasonryLayout {
  static let rowHeight: CGFloat = 168
  static let itemSpacing: CGFloat = 12
  static let verticalPadding: CGFloat = 4

  static func thumbnailWidth(for image: GalleryImage) -> CGFloat {
    let widths: [CGFloat] = [108, 128, 148, 118, 162, 132, 152, 138, 124]
    return widths[abs(image.id) % widths.count]
  }

  static func leadingOffset(forSelectedIndex index: Int, in images: [GalleryImage]) -> CGFloat {
    guard index > 0, !images.isEmpty else { return 0 }
    let clampedIndex = min(max(index, 0), images.count - 1)
    var offset: CGFloat = 0
    for imageIndex in 0..<clampedIndex {
      offset += thumbnailWidth(for: images[imageIndex]) + itemSpacing
    }
    return offset
  }

  static func selectedImageWidth(at index: Int, in images: [GalleryImage]) -> CGFloat {
    guard !images.isEmpty else { return 0 }
    let clampedIndex = min(max(index, 0), images.count - 1)
    return thumbnailWidth(for: images[clampedIndex])
  }
}

enum HomeEngagementFormatting {
  static func formatCount(_ count: Int) -> String {
    if count >= 10_000 {
      let value = Double(count) / 10_000
      return value.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f万", value)
        : String(format: "%.1f万", value)
    }
    if count >= 1_000 {
      let value = Double(count) / 1_000
      return value.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0fk", value)
        : String(format: "%.1fk", value)
    }
    return "\(count)"
  }
}

struct HomeImageEngagementOverlay: View {
  let engagementKey: String
  let onLike: () -> Void
  let onFavorite: () -> Void
  let onChat: () -> Void

  @EnvironmentObject private var engagementStore: ImageEngagementStore

  var body: some View {
    HStack(spacing: 0) {
      HomeEngagementOverlayButton(
        icon: "heart",
        activeIcon: "heart.fill",
        iconColor: Color(red: 0.98, green: 0.45, blue: 0.50),
        label: "点赞",
        value: HomeEngagementFormatting.formatCount(engagementStore.likeCount(for: engagementKey)),
        isActive: engagementStore.isLiked(engagementKey),
        action: onLike
      )
      .frame(maxWidth: .infinity)

      HomeEngagementOverlayButton(
        icon: "bookmark",
        activeIcon: "bookmark.fill",
        iconColor: Color(red: 0.98, green: 0.72, blue: 0.28),
        label: "收藏",
        value: HomeEngagementFormatting.formatCount(engagementStore.favoriteCount(for: engagementKey)),
        isActive: engagementStore.isFavorited(engagementKey),
        action: onFavorite
      )
      .frame(maxWidth: .infinity)

      HomeEngagementOverlayButton(
        icon: "bubble.left.and.bubble.right",
        activeIcon: "bubble.left.and.bubble.right.fill",
        iconColor: Color(red: 0.55, green: 0.75, blue: 1.0),
        label: "聊天",
        value: HomeEngagementFormatting.formatCount(engagementStore.commentCount(for: engagementKey)),
        isActive: false,
        action: onChat
      )
      .frame(maxWidth: .infinity)
    }
    .id(engagementKey)
  }
}

private struct HomeEngagementOverlayButton: View {
  let icon: String
  let activeIcon: String
  let iconColor: Color
  let label: String
  let value: String
  let isActive: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 3) {
        Image(systemName: isActive ? activeIcon : icon)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(isActive ? iconColor : .white.opacity(0.92))
          .frame(width: 14, height: 14)

        Text(value)
          .font(.system(size: 11, weight: .bold))
          .monospacedDigit()
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.75)
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .accessibilityValue(value)
  }
}

struct HomeHorizontalMasonryView: View {
  let images: [GalleryImage]
  @Binding var selectedIndex: Int
  var canMoveImage: (GalleryImage) -> Bool = { _ in false }
  var showsAuthorOverlay: Bool = false
  var showsLocationOverlay: Bool = false
  var showsPublishedBadge: Bool = false
  var showsEngagementOverlay: Bool = false
  var showsExpandButton: Bool = false
  var onAuthorTap: ((GalleryImage) -> Void)?
  var onLocationTap: ((GalleryImage) -> Void)?
  var onLike: ((GalleryImage) -> Void)?
  var onFavorite: ((GalleryImage) -> Void)?
  var onChat: ((GalleryImage) -> Void)?
  var onExpandTap: ((GalleryImage, Int) -> Void)?
  var onImageTap: ((GalleryImage, Int) -> Void)?
  var onImageDoubleTap: ((GalleryImage, Int) -> Void)?

  @AppStorage(UserSession.userNicknameKey) private var userNickname = ""

  private let rowHeight = HomeMasonryLayout.rowHeight
  private let itemSpacing = HomeMasonryLayout.itemSpacing

  var emptyMessage: String = "暂无图片"

  var body: some View {
    Group {
      if images.isEmpty {
        emptyPlaceholder
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(spacing: itemSpacing) {
            ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
              masonryCell(for: image, index: index)
            }
          }
          .padding(.vertical, HomeMasonryLayout.verticalPadding)
        }
        .frame(height: rowHeight + 8)
      }
    }
  }

  private var emptyPlaceholder: some View {
    Text(emptyMessage)
      .font(.caption)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity)
      .frame(height: rowHeight + 8)
      .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private func thumbnailWidth(for image: GalleryImage) -> CGFloat {
    HomeMasonryLayout.thumbnailWidth(for: image)
  }

  @ViewBuilder
  private func masonryCell(for image: GalleryImage, index: Int) -> some View {
    let isSelected = selectedIndex == index
    let width = thumbnailWidth(for: image)

    ZStack(alignment: .bottom) {
      GalleryThumbnailImage(url: image.url)
        .frame(width: width, height: rowHeight)
        .clipped()

      LinearGradient(
        colors: showsEngagementOverlay
          ? [.clear, .black.opacity(0.28), .black.opacity(0.78)]
          : [.clear, .black.opacity(0.62)],
        startPoint: .top,
        endPoint: .bottom
      )
      .allowsHitTesting(false)

      VStack(alignment: .leading, spacing: 4) {
        if showsEngagementOverlay, let onLike, let onFavorite, let onChat {
          HomeImageEngagementOverlay(
            engagementKey: image.engagementKey,
            onLike: { onLike(image) },
            onFavorite: { onFavorite(image) },
            onChat: { onChat(image) }
          )
        }

        HStack(alignment: .bottom, spacing: 6) {
          VStack(alignment: .leading, spacing: 3) {
            Text(image.title)
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.white)
              .lineLimit(1)

            if showsLocationOverlay, image.hasLocation, let onLocationTap {
              Button {
                onLocationTap(image)
              } label: {
                HStack(spacing: 3) {
                  Image(systemName: "mappin.and.ellipse")
                  Text(image.locationLabel)
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
              }
              .buttonStyle(.plain)
            }
          }
          .frame(maxWidth: showsAuthorOverlay ? width * 0.52 : .infinity, alignment: .leading)

          Spacer(minLength: 0)

          if showsAuthorOverlay {
            authorOverlayButton(for: image, maxWidth: width * 0.46)
          }
        }
      }
      .padding(.horizontal, 8)
      .padding(.bottom, 8)

      GalleryMediaTypeChrome(image: image, compact: true)
    }
    .frame(width: width, height: rowHeight)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(alignment: .topTrailing) {
      if showsPublishedBadge, image.isPublished {
        Text("已发布")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(Color(red: 0.18, green: 0.72, blue: 0.45), in: Capsule())
          .padding(8)
      } else if showsExpandButton, onImageDoubleTap == nil, let onExpandTap {
        expandButton(image: image) {
          onExpandTap(image, index)
        }
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(
          isSelected ? Color(red: 0.28, green: 0.48, blue: 0.98) : .clear,
          lineWidth: 3
        )
    }
    .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .modifier(
      HomeMasonryCellTapModifier(
        onSingleTap: {
          withAnimation(.easeInOut(duration: 0.2)) {
            selectedIndex = index
          }
          onImageTap?(image, index)
        },
        onDoubleTap: onImageDoubleTap.map { handler in
          { handler(image, index) }
        }
      )
    )
    .modifier(HomeMasonryDragModifier(
      engagementKey: image.engagementKey,
      enabled: canMoveImage(image)
    ))
  }

  private func expandButton(image: GalleryImage, onExpand: @escaping () -> Void) -> some View {
    Button(action: onExpand) {
      Image(systemName: "arrow.up.left.and.arrow.down.right")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 32, height: 32)
        .background(Color(red: 0.28, green: 0.48, blue: 0.98), in: Circle())
        .overlay {
          Circle()
            .strokeBorder(.white.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
    }
    .buttonStyle(.plain)
    .padding(8)
    .accessibilityLabel("全屏查看 \(image.title)")
  }

  @ViewBuilder
  private func authorOverlayButton(for image: GalleryImage, maxWidth: CGFloat) -> some View {
    if let onAuthorTap {
      Button {
        onAuthorTap(image)
      } label: {
        authorOverlay(for: image, maxWidth: maxWidth)
      }
      .buttonStyle(.plain)
    } else {
      authorOverlay(for: image, maxWidth: maxWidth)
    }
  }

  private func authorOverlay(for image: GalleryImage, maxWidth: CGFloat) -> some View {
    let authorName = image.authorDisplayName(currentUserNickname: userNickname)

    return HStack(spacing: 4) {
      UserAvatarView(
        name: authorName,
        size: 16,
        useSessionAvatar: image.usesSessionAvatarForAuthor
      )

      Text("@\(authorName)")
        .font(.system(size: 10, weight: .semibold))
        .lineLimit(1)
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 6)
    .padding(.vertical, 4)
    .background(.black.opacity(0.48), in: Capsule())
    .frame(maxWidth: maxWidth, alignment: .trailing)
  }
}

private struct HomeMasonryCellTapModifier: ViewModifier {
  let onSingleTap: () -> Void
  let onDoubleTap: (() -> Void)?

  @State private var pendingSingleTap: Task<Void, Never>?

  func body(content: Content) -> some View {
    if let onDoubleTap {
      content
        .onTapGesture(count: 2) {
          pendingSingleTap?.cancel()
          pendingSingleTap = nil
          onDoubleTap()
        }
        .onTapGesture(count: 1) {
          pendingSingleTap?.cancel()
          pendingSingleTap = Task {
            try? await Task.sleep(nanoseconds: 260_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
              onSingleTap()
            }
          }
        }
    } else {
      content.onTapGesture(perform: onSingleTap)
    }
  }
}

private struct HomeMasonryDragModifier: ViewModifier {
  let engagementKey: String
  let enabled: Bool

  func body(content: Content) -> some View {
    if enabled {
      content.draggable(engagementKey)
    } else {
      content
    }
  }
}
