//
//  ProfileStatsService.swift
//  b-app-search
//

import Foundation

struct ProfileStats: Equatable {
  let likeCount: Int
  let shareCount: Int
  let favoriteCount: Int
  let commentCount: Int

  static let zero = ProfileStats(likeCount: 0, shareCount: 0, favoriteCount: 0, commentCount: 0)
}

enum ProfileStatsService {
  @MainActor
  static func stats(
    for identity: PublicProfileIdentity,
    galleryStore: GalleryStore,
    engagementStore: ImageEngagementStore
  ) -> ProfileStats {
    if identity.isCurrentUser {
      return stats(for: galleryStore.sharedUserImages, engagementStore: engagementStore)
    }

    let index = identity.sampleIndex ?? 0
    let images = GalleryImage.samples.filter { $0.sampleAuthorIndex == index }
    let base = stats(for: images, engagementStore: engagementStore)
    let multiplier = index + 3
    return ProfileStats(
      likeCount: max(base.likeCount, 120 * multiplier),
      shareCount: max(base.shareCount, images.count + 8 * multiplier),
      favoriteCount: max(base.favoriteCount, 45 * multiplier),
      commentCount: max(base.commentCount, 18 * multiplier)
    )
  }

  @MainActor
  private static func stats(
    for images: [GalleryImage],
    engagementStore: ImageEngagementStore
  ) -> ProfileStats {
    var likes = 0
    var favorites = 0
    var comments = 0
    for image in images {
      likes += engagementStore.likeCount(for: image.engagementKey)
      favorites += engagementStore.favoriteCount(for: image.engagementKey)
      comments += engagementStore.commentCount(for: image.engagementKey)
    }
    return ProfileStats(
      likeCount: likes,
      shareCount: images.count,
      favoriteCount: favorites,
      commentCount: comments
    )
  }
}
