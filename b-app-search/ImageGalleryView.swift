//
//  ImageGalleryView.swift
//  b-app-search
//

import CoreLocation
import SwiftUI
import UIKit

/// 媒体内容类型：封面图共用 `url`；音频/视频资源走可选 `mediaURL`。
enum GalleryMediaType: String, CaseIterable, Hashable, Codable, Identifiable {
  case photo
  case music
  case video

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .photo: return "图片"
    case .music: return "音乐"
    case .video: return "视频"
    }
  }

  var badgeSystemImage: String {
    switch self {
    case .photo: return "photo"
    case .music: return "music.note"
    case .video: return "play.rectangle.fill"
    }
  }

  static func parse(_ raw: String?) -> GalleryMediaType {
    guard let raw, let value = GalleryMediaType(rawValue: raw.lowercased()) else { return .photo }
    return value
  }
}

/// 图片地图标注分类，用于 pointer layer 样式区分。
enum GalleryImageCategory: String, CaseIterable, Hashable, Identifiable {
  case landscape
  case culture
  case urban
  case architecture

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .landscape: return "地理风光"
    case .culture: return "人文纪实"
    case .urban: return "城市建筑"
    case .architecture: return "地标建筑"
    }
  }

  var pinColor: Color {
    switch self {
    case .landscape: return Color(red: 0.18, green: 0.72, blue: 0.45)
    case .culture: return Color(red: 0.92, green: 0.28, blue: 0.32)
    case .urban: return Color(red: 0.22, green: 0.48, blue: 0.95)
    case .architecture: return Color(red: 0.95, green: 0.55, blue: 0.12)
    }
  }

  var iconName: String {
    switch self {
    case .landscape: return "leaf.fill"
    case .culture: return "person.2.fill"
    case .urban: return "building.2.fill"
    case .architecture: return "building.columns.fill"
    }
  }

  static func from(tag: String) -> GalleryImageCategory {
    switch tag {
    case "城市": return .urban
    case "街拍": return .culture
    case "建筑": return .architecture
    case "自然", "户外", "风光", "植物": return .landscape
    default: return .landscape
    }
  }
}

struct GalleryImage: Identifiable, Hashable {
  let id: Int
  /// 点赞/评论等互动的唯一键，与样例图 numeric id 隔离，避免冲突。
  let engagementKey: String
  let title: String
  let tag: String
  let description: String
  /// 封面图（photo / music / video 共用）
  let url: URL
  /// 媒体类型；未接入真实数据前默认 `.photo`
  let mediaType: GalleryMediaType
  /// 音乐/视频的实际资源地址；封面仍使用 `url`
  let mediaURL: URL?
  let latitude: Double
  let longitude: Double
  let locationName: String?
  /// 经纬度来自图片 EXIF，不可手动修改。
  let hasEmbeddedLocation: Bool
  let category: GalleryImageCategory
  let isPublished: Bool
  let isCloudSynced: Bool
  let folderId: String?

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  var hasLocation: Bool {
    latitude != 0 || longitude != 0
  }

  var locationLabel: String {
    if let locationName, !locationName.isEmpty {
      return locationName
    }
    return String(format: "%.2f°, %.2f°", latitude, longitude)
  }

  static let samples: [GalleryImage] = [
    GalleryImage(
      id: 1, title: "城市天际线", tag: "城市",
      description: "黄昏时分的摩天大楼与河面倒影。",
      url: URL(string: "https://picsum.photos/seed/city/600/420")!,
      latitude: 39.9042, longitude: 116.4074,
      locationName: "东城区"
    ),
    GalleryImage(
      id: 2, title: "海岸线", tag: "自然",
      description: "浪花拍岸，适合用作旅行封面。",
      url: URL(string: "https://picsum.photos/seed/coast/600/780")!,
      latitude: 39.8825, longitude: 116.4258,
      locationName: "朝阳区"
    ),
    GalleryImage(
      id: 3, title: "森林小径", tag: "户外",
      description: "林间光影交错，氛围宁静治愈。",
      url: URL(string: "https://picsum.photos/seed/forest/600/520")!,
      latitude: 39.9286, longitude: 116.3889,
      locationName: "海淀区"
    ),
    GalleryImage(
      id: 4, title: "雪山", tag: "风光",
      description: "雪峰与云海，冷色调构图。",
      url: URL(string: "https://picsum.photos/seed/mountain/600/860")!,
      latitude: 39.9512, longitude: 116.3521,
      locationName: "昌平区"
    ),
    GalleryImage(
      id: 5, title: "沙漠", tag: "自然",
      description: "金色沙丘延伸至地平线。",
      url: URL(string: "https://picsum.photos/seed/desert/600/480")!,
      latitude: 39.8718, longitude: 116.3624,
      locationName: "丰台区"
    ),
    GalleryImage(
      id: 6, title: "湖泊", tag: "风光",
      description: "湖面如镜，倒映天空与远山。",
      url: URL(string: "https://picsum.photos/seed/lake/600/640")!,
      latitude: 39.9146, longitude: 116.4342,
      locationName: "通州区"
    ),
    GalleryImage(
      id: 7, title: "街景", tag: "街拍",
      description: "雨后街道的霓虹与行人剪影。",
      url: URL(string: "https://picsum.photos/seed/street/600/720")!,
      latitude: 39.9097, longitude: 116.4036,
      locationName: "西城区",
      mediaType: .music,
      mediaURL: URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3")
    ),
    GalleryImage(
      id: 8, title: "桥梁", tag: "建筑",
      description: "钢结构桥梁横跨江面，线条硬朗。",
      url: URL(string: "https://picsum.photos/seed/bridge/600/500")!,
      latitude: 39.9364, longitude: 116.4128,
      locationName: "顺义区",
      mediaType: .video,
      mediaURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")
    ),
    GalleryImage(
      id: 9, title: "花田", tag: "植物",
      description: "春日花田，色彩柔和适合壁纸。",
      url: URL(string: "https://picsum.photos/seed/flowers/600/680")!,
      latitude: 39.9183, longitude: 116.4215,
      locationName: "大兴区"
    ),
    GalleryImage(
      id: 10, title: "夜色天际", tag: "城市",
      description: "灯火渐起，城市轮廓被夜色勾勒。",
      url: URL(string: "https://picsum.photos/seed/citynight/600/540")!,
      latitude: 39.9075, longitude: 116.3972,
      locationName: "东城区"
    ),
    GalleryImage(
      id: 11, title: "河谷清晨", tag: "自然",
      description: "薄雾散去，河谷在晨光里舒展开来。",
      url: URL(string: "https://picsum.photos/seed/valley/600/700")!,
      latitude: 39.8850, longitude: 116.4301,
      locationName: "朝阳区"
    ),
    GalleryImage(
      id: 12, title: "云海峰线", tag: "风光",
      description: "山脊隐入云海，远近层次分明。",
      url: URL(string: "https://picsum.photos/seed/cloudridge/600/620")!,
      latitude: 39.9480, longitude: 116.3605,
      locationName: "昌平区"
    )
  ]

  init(
    id: Int,
    title: String,
    tag: String,
    description: String,
    url: URL,
    latitude: Double,
    longitude: Double,
    locationName: String? = nil,
    hasEmbeddedLocation: Bool = false,
    category: GalleryImageCategory? = nil,
    isPublished: Bool = false,
    isCloudSynced: Bool = false,
    engagementKey: String? = nil,
    folderId: String? = nil,
    mediaType: GalleryMediaType = .photo,
    mediaURL: URL? = nil
  ) {
    self.id = id
    self.engagementKey = engagementKey ?? Self.defaultEngagementKey(for: id)
    self.title = title
    self.tag = tag
    self.description = description
    self.url = url
    self.mediaType = mediaType
    self.mediaURL = mediaURL
    self.latitude = latitude
    self.longitude = longitude
    self.locationName = locationName
    self.hasEmbeddedLocation = hasEmbeddedLocation
    self.category = category ?? GalleryImageCategory.from(tag: tag)
    self.isPublished = isPublished
    self.isCloudSynced = isCloudSynced
    self.folderId = folderId
  }

  func updating(
    latitude: Double? = nil,
    longitude: Double? = nil,
    locationName: String?? = nil,
    hasEmbeddedLocation: Bool? = nil,
    isPublished: Bool? = nil,
    isCloudSynced: Bool? = nil,
    folderId: String? = nil,
    mediaType: GalleryMediaType? = nil,
    mediaURL: URL?? = nil
  ) -> GalleryImage {
    GalleryImage(
      id: id,
      title: title,
      tag: tag,
      description: description,
      url: url,
      latitude: latitude ?? self.latitude,
      longitude: longitude ?? self.longitude,
      locationName: locationName ?? self.locationName,
      hasEmbeddedLocation: hasEmbeddedLocation ?? self.hasEmbeddedLocation,
      category: category,
      isPublished: isPublished ?? self.isPublished,
      isCloudSynced: isCloudSynced ?? self.isCloudSynced,
      engagementKey: engagementKey,
      folderId: folderId ?? self.folderId,
      mediaType: mediaType ?? self.mediaType,
      mediaURL: mediaURL ?? self.mediaURL
    )
  }

  private static func defaultEngagementKey(for id: Int) -> String {
    id >= 10_000 ? "user-\(id)" : "sample-\(id)"
  }
}

extension GalleryImage {
  static let sampleAuthorNames = [
    "山雾摄影", "光影旅人", "City Lens", "镜头里的风", "北方行记",
    "慢快门", "行走的记录者", "一拍即合", "拾光者"
  ]

  static let sampleAuthorLocations = [
    "北京", "上海", "广州", "成都", "杭州", "深圳", "西安", "南京", "厦门"
  ]

  var sampleAuthorIndex: Int {
    abs(id) % Self.sampleAuthorNames.count
  }

  var isUserOwnedImage: Bool {
    engagementKey.hasPrefix("user-") || id >= 10_000
  }

  func authorDisplayName(currentUserNickname: String) -> String {
    if isUserOwnedImage {
      let nickname = currentUserNickname.trimmingCharacters(in: .whitespacesAndNewlines)
      return nickname.isEmpty ? "我" : nickname
    }
    return Self.sampleAuthorNames[sampleAuthorIndex]
  }

  func authorProfileIdentity(currentUserNickname: String) -> PublicProfileIdentity {
    if isUserOwnedImage {
      return .currentUser
    }
    return .sample(index: sampleAuthorIndex)
  }

  var usesSessionAvatarForAuthor: Bool {
    isUserOwnedImage
  }
}

struct ImageGalleryView: View {
  @EnvironmentObject private var galleryStore: GalleryStore

  private let horizontalInset: CGFloat = 16
  private let rowGap: CGFloat = 12

  @State private var selectedMediaDestination: GalleryMediaOpenDestination?
  @State private var mapLocationImage: GalleryImage?
  @State private var showManageGallery = false

  private var images: [GalleryImage] {
    galleryStore.publicImages
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        if galleryStore.userImages.isEmpty {
          Button {
            showManageGallery = true
          } label: {
            HStack(spacing: 12) {
              Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(Color(red: 0.28, green: 0.48, blue: 0.98))
              VStack(alignment: .leading, spacing: 4) {
                Text("添加你的图片")
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(.primary)
                Text("上传后可在「发布」中批量公开到共享图片页")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .multilineTextAlignment(.leading)
              }
              Spacer()
              Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .buttonStyle(.plain)
          .padding(.horizontal, horizontalInset)
          .padding(.top, rowGap)
        }

        GalleryWaterfallView(
          images: images,
          horizontalInset: horizontalInset,
          onImageTap: { selectedMediaDestination = .open($0, in: images) },
          onSimilarGroupTap: { group in
            guard let cover = group.first else { return }
            selectedMediaDestination = .open(cover, in: group)
          },
          onLocationTap: { mapLocationImage = $0 }
        )
        .padding(.vertical, rowGap)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("共享图片")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button {
            showManageGallery = true
          } label: {
            Label("添加", systemImage: "plus.circle.fill")
          }
        }
      }
      .navigationDestination(isPresented: $showManageGallery) {
        GalleryManageView()
          .environmentObject(galleryStore)
      }
      .fullScreenCover(item: $selectedMediaDestination) { destination in
        GalleryMediaDestinationView(
          destination: destination,
          onLocationTap: { mapLocationImage = $0 }
        )
      }
      .fullScreenCover(item: $mapLocationImage) { image in
        MapLocationDetailView(image: image)
      }
    }
  }
}

// MARK: - Shared thumbnail loader

struct GalleryThumbnailImage: View {
  let url: URL

  var body: some View {
    Group {
      if url.isFileURL, let uiImage = UIImage(contentsOfFile: url.path) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()
      } else {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let loadedImage):
            loadedImage
              .resizable()
              .scaledToFill()
          case .failure:
            placeholder
          default:
            placeholder
              .overlay { ProgressView() }
          }
        }
      }
    }
  }

  private var placeholder: some View {
    Color(.secondarySystemGroupedBackground)
      .overlay {
        Image(systemName: "photo")
          .font(.title2)
          .foregroundStyle(.secondary)
      }
  }
}

// MARK: - Similar image groups

/// 相似图片群组：同标签视为相似，叠成一组展示。
struct GallerySimilarImageGroup: Identifiable, Hashable {
  let id: String
  let images: [GalleryImage]

  var cover: GalleryImage { images[0] }
  var isCluster: Bool { images.count > 1 }
}

enum SimilarImageGrouper {
  /// 按标签聚合；保持首次出现顺序。单张也包成 group，便于统一布局。
  static func groups(from images: [GalleryImage]) -> [GallerySimilarImageGroup] {
    var buckets: [String: [GalleryImage]] = [:]
    var order: [String] = []

    for image in images {
      let key = similarityKey(for: image)
      if buckets[key] == nil {
        order.append(key)
        buckets[key] = []
      }
      buckets[key]?.append(image)
    }

    return order.compactMap { key in
      guard let items = buckets[key], !items.isEmpty else { return nil }
      return GallerySimilarImageGroup(id: key, images: items)
    }
  }

  static func similarityKey(for image: GalleryImage) -> String {
    let tag = image.tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if tag.isEmpty {
      return "id:\(image.engagementKey)"
    }
    return "tag:\(tag)"
  }
}

// MARK: - Waterfall grid

struct GalleryWaterfallView: View {
  let images: [GalleryImage]
  var columnCount: Int = 2
  var horizontalInset: CGFloat = 16
  var columnGap: CGFloat = 12
  var rowGap: CGFloat = 12
  /// 将同标签相似图叠成群组；管理页等场景可关闭。
  var groupSimilarImages: Bool = true
  var onImageTap: (GalleryImage) -> Void
  /// 点击相似群组时回调（整组图片）；未设置则仅打开封面。
  var onSimilarGroupTap: (([GalleryImage]) -> Void)? = nil
  var onLocationTap: (GalleryImage) -> Void = { _ in }

  private var displayGroups: [GallerySimilarImageGroup] {
    guard groupSimilarImages else {
      return images.map {
        GallerySimilarImageGroup(id: "solo:\($0.engagementKey)", images: [$0])
      }
    }
    return SimilarImageGrouper.groups(from: images)
  }

  private var masonryColumns: [[GallerySimilarImageGroup]] {
    var columns = Array(repeating: [GallerySimilarImageGroup](), count: columnCount)
    var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)

    for group in displayGroups {
      let shortest = columnHeights.enumerated().min(by: { $0.element < $1.element })!.offset
      columns[shortest].append(group)
      columnHeights[shortest] += cellHeight(for: group) + rowGap
    }
    return columns
  }

  var body: some View {
    HStack(alignment: .top, spacing: columnGap) {
      ForEach(Array(masonryColumns.enumerated()), id: \.offset) { _, columnGroups in
        VStack(spacing: rowGap) {
          ForEach(columnGroups) { group in
            if group.isCluster {
              GallerySimilarGroupThumbnail(
                group: group,
                height: cellHeight(for: group),
                onOpen: { openGroup(group) },
                onLocationTap: onLocationTap
              )
            } else {
              GalleryThumbnail(
                image: group.cover,
                height: cellHeight(for: group),
                onOpen: { onImageTap(group.cover) },
                onLocationTap: onLocationTap
              )
            }
          }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
      }
    }
    .padding(.horizontal, horizontalInset)
    .id(displayGroups.map(\.id))
  }

  private func openGroup(_ group: GallerySimilarImageGroup) {
    if let onSimilarGroupTap {
      onSimilarGroupTap(group.images)
    } else {
      onImageTap(group.cover)
    }
  }

  private func cellHeight(for group: GallerySimilarImageGroup) -> CGFloat {
    let heights: [CGFloat] = [148, 212, 176, 228, 160, 196, 184, 220, 168]
    let base = heights[abs(group.cover.id) % heights.count]
    return group.isCluster ? base + 10 : base
  }
}

/// 相似群组堆叠卡片：背后露出 1–2 张，角标显示张数。
private struct GallerySimilarGroupThumbnail: View {
  let group: GallerySimilarImageGroup
  let height: CGFloat
  var onOpen: () -> Void
  var onLocationTap: (GalleryImage) -> Void

  private let cornerRadius: CGFloat = 14
  private var stackDepth: Int { min(2, group.images.count - 1) }

  var body: some View {
    ZStack(alignment: .bottom) {
      ForEach(0..<stackDepth, id: \.self) { layer in
        let offset = CGFloat(stackDepth - layer)
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(Color(.tertiarySystemFill))
          .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
          }
          .frame(maxWidth: .infinity)
          .frame(height: height - 10)
          .padding(.horizontal, offset * 5)
          .offset(y: -offset * 5)
          .opacity(0.9 - Double(layer) * 0.12)
      }

      GalleryThumbnail(
        image: group.cover,
        height: height - 10,
        onOpen: onOpen,
        onLocationTap: onLocationTap
      )
      .padding(.top, CGFloat(stackDepth) * 5)
    }
    .frame(maxWidth: .infinity)
    .frame(height: height)
    .overlay(alignment: .topTrailing) {
      Text("\(group.images.count) 张相似")
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.62), in: Capsule())
        .padding(.top, CGFloat(stackDepth) * 5 + 8)
        .padding(.trailing, 8)
        .allowsHitTesting(false)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(group.cover.tag)，\(group.images.count) 张相似图片")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction(named: "打开相似组", onOpen)
  }
}

// MARK: - Grid thumbnail

struct GalleryThumbnail: View {
  let image: GalleryImage
  let height: CGFloat
  var onOpen: () -> Void
  var onLocationTap: (GalleryImage) -> Void

  private let cornerRadius: CGFloat = 14

  var body: some View {
    ZStack(alignment: .bottom) {
      thumbnailImage
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture(perform: onOpen)

      GalleryImageOverlay(
        image: image,
        compactActions: true,
        onLocationTap: { onLocationTap(image) }
      )

      // 叠在最上层，避免底部信息条拦截 music 播控点击
      GalleryMediaTypeChrome(image: image)
    }
    .frame(maxWidth: .infinity)
    .frame(height: height)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
  }

  private var thumbnailImage: some View {
    Color(.secondarySystemGroupedBackground)
      .overlay {
        GalleryThumbnailImage(url: image.url)
      }
      .clipped()
  }
}

// MARK: - Image overlay (tag, description, actions)

private struct GalleryImageOverlay: View {
  let image: GalleryImage
  var compactActions: Bool
  var onLocationTap: (() -> Void)?

  @EnvironmentObject private var engagementStore: ImageEngagementStore
  @State private var showShareHint = false
  @State private var showBeautifyHint = false

  var body: some View {
    ZStack(alignment: .bottom) {
      LinearGradient(
        colors: [.clear, .black.opacity(0.15), .black.opacity(0.72)],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
      .allowsHitTesting(false)

      HStack(alignment: .bottom, spacing: 10) {
        VStack(alignment: .leading, spacing: 6) {
          GalleryImageTagBadge(
            image: image,
            compact: compactActions,
            onLocationTap: onLocationTap
          )

          Text(image.description)
            .font(compactActions ? .caption : .subheadline)
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(compactActions ? 2 : 3)
            .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        GalleryActionButtons(
          iconSize: compactActions ? 14 : 18,
          buttonSize: compactActions ? 34 : 40,
          isLiked: engagementStore.isLiked(image.engagementKey),
          likeCountLabel: HomeEngagementFormatting.formatCount(
            engagementStore.likeCount(for: image.engagementKey)
          ),
          onLike: {
            _ = engagementStore.toggleLike(for: image.engagementKey)
          },
          onShare: { showShareHint = true },
          onBeautify: { showBeautifyHint = true }
        )
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 12)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .alert("分享", isPresented: $showShareHint) {
      Button("确定", role: .cancel) {}
    } message: {
      Text("分享「\(image.title)」功能待接入")
    }
    .alert("图片美化", isPresented: $showBeautifyHint) {
      Button("确定", role: .cancel) {}
    } message: {
      Text("即将进入「\(image.title)」美化编辑")
    }
  }
}

/// 图片左下角分类 logo：限制最大宽高，文字溢出省略，hover 展开完整文案。
private struct GalleryImageTagBadge: View {
  let image: GalleryImage
  var compact: Bool
  var onLocationTap: (() -> Void)?

  @State private var isHovering = false

  private var collapsedMaxWidth: CGFloat { compact ? 120 : 156 }
  private var maxHeight: CGFloat { compact ? 22 : 26 }
  private var iconSide: CGFloat { compact ? 12 : 14 }

  private var labelText: String {
    var parts = [image.tag, image.category.displayName]
    if image.hasLocation {
      parts.append(image.locationLabel)
    }
    return parts.joined(separator: " · ")
  }

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: image.category.iconName)
        .font(.system(size: compact ? 9 : 10, weight: .semibold))
        .frame(width: iconSide, height: iconSide)

      Text(labelText)
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: .infinity, alignment: .leading)

      if image.hasLocation, onLocationTap != nil {
        Image(systemName: "mappin.and.ellipse")
          .font(.system(size: compact ? 9 : 10, weight: .semibold))
          .frame(width: iconSide, height: iconSide)
      }
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .frame(
      maxWidth: isHovering ? 280 : collapsedMaxWidth,
      maxHeight: maxHeight,
      alignment: .leading
    )
    .background(image.category.pinColor.opacity(isHovering ? 0.82 : 0.55), in: Capsule())
    .clipShape(Capsule())
    .contentShape(Capsule())
    .animation(.easeInOut(duration: 0.16), value: isHovering)
    .onHover { hovering in
      isHovering = hovering
    }
    .onTapGesture {
      if image.hasLocation {
        onLocationTap?()
      }
    }
    .help(labelText)
    .accessibilityLabel(labelText)
  }
}

private struct GalleryActionButtons: View {
  var iconSize: CGFloat = 16
  var buttonSize: CGFloat = 36
  var isLiked: Bool = false
  var likeCountLabel: String = ""
  var onLike: (() -> Void)?
  let onShare: () -> Void
  let onBeautify: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      if let onLike {
        Button(action: onLike) {
          VStack(spacing: 2) {
            Image(systemName: isLiked ? "heart.fill" : "heart")
              .font(.system(size: iconSize, weight: .semibold))
              .foregroundStyle(isLiked ? Color(red: 0.98, green: 0.35, blue: 0.42) : .white)
              .frame(width: buttonSize, height: buttonSize)
              .background(.ultraThinMaterial, in: Circle())
              .overlay {
                Circle()
                  .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
              }
            if !likeCountLabel.isEmpty {
              Text(likeCountLabel)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .monospacedDigit()
            }
          }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLiked ? "取消点赞" : "点赞")
      }

      overlayIconButton(systemName: "square.and.arrow.up", action: onShare)
      overlayIconButton(systemName: "wand.and.stars", action: onBeautify)
    }
  }

  private func overlayIconButton(systemName: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: iconSize, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: buttonSize, height: buttonSize)
        .background(.ultraThinMaterial, in: Circle())
        .overlay {
          Circle()
            .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
        }
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Fullscreen viewer

struct ImageViewer: View {
  let images: [GalleryImage]
  let initialImage: GalleryImage
  var onLocationTap: ((GalleryImage) -> Void)?
  var onCurrentImageChanged: ((GalleryImage) -> Void)?

  @Environment(\.dismiss) private var dismiss
  @State private var currentID: Int

  init(
    images: [GalleryImage],
    initialImage: GalleryImage,
    onLocationTap: ((GalleryImage) -> Void)? = nil,
    onCurrentImageChanged: ((GalleryImage) -> Void)? = nil
  ) {
    self.images = images
    self.initialImage = initialImage
    self.onLocationTap = onLocationTap
    self.onCurrentImageChanged = onCurrentImageChanged
    _currentID = State(initialValue: initialImage.id)
  }

  private var currentImage: GalleryImage? {
    images.first(where: { $0.id == currentID })
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      TabView(selection: $currentID) {
        ForEach(images) { image in
          ZoomableAsyncImage(url: image.url)
            .tag(image.id)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .automatic))
      .onChange(of: currentID) { newID in
        if let image = images.first(where: { $0.id == newID }) {
          onCurrentImageChanged?(image)
        }
      }

      VStack {
        HStack {
          Spacer()
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.title)
              .symbolRenderingMode(.palette)
              .foregroundStyle(.white, .white.opacity(0.35))
          }
          .padding(20)
        }

        Spacer()

        if let image = currentImage {
          GalleryImageOverlay(
            image: image,
            compactActions: false,
            onLocationTap: image.hasLocation ? { onLocationTap?(image) } : nil
          )
            .padding(.horizontal, 20)
            .padding(.bottom, 48)
        }
      }
    }
  }
}

private struct ZoomableAsyncImage: View {
  let url: URL

  @State private var scale: CGFloat = 1

  var body: some View {
    Group {
      if url.isFileURL, let uiImage = UIImage(contentsOfFile: url.path) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFit()
          .scaleEffect(scale)
          .gesture(
            MagnificationGesture()
              .onChanged { value in
                scale = min(max(value, 1), 4)
              }
          )
          .onTapGesture(count: 2) {
            withAnimation {
              scale = scale > 1 ? 1 : 2
            }
          }
      } else {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .scaledToFit()
              .scaleEffect(scale)
              .gesture(
                MagnificationGesture()
                  .onChanged { value in
                    scale = min(max(value, 1), 4)
                  }
              )
              .onTapGesture(count: 2) {
                withAnimation {
                  scale = scale > 1 ? 1 : 2
                }
              }
          case .failure:
            imagePlaceholder
          default:
            imagePlaceholder
              .overlay { ProgressView().tint(.white) }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var imagePlaceholder: some View {
    Color.black
      .overlay {
        Image(systemName: "photo")
          .font(.largeTitle)
          .foregroundStyle(.white.opacity(0.5))
      }
  }
}

struct ImageGalleryView_Previews: PreviewProvider {
  static var previews: some View {
    ImageGalleryView()
      .environmentObject(GalleryStore.shared)
  }
}
