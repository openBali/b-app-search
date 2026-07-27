//
//  ImageEngagementStore.swift
//  b-app-search
//

import Foundation
import SwiftUI

struct ImageCommentRecord: Identifiable, Codable, Equatable {
  let id: UUID
  let engagementKey: String
  let author: String
  let content: String
  let createdAt: Date
  let isMine: Bool

  var timeLabel: String {
    let interval = Date().timeIntervalSince(createdAt)
    if interval < 60 { return "刚刚" }
    if interval < 3600 { return "\(Int(interval / 60)) 分钟前" }
    if interval < 86_400 { return "\(Int(interval / 3600)) 小时前" }
    let formatter = DateFormatter()
    formatter.dateFormat = "MM-dd HH:mm"
    return formatter.string(from: createdAt)
  }

  init(
    id: UUID = UUID(),
    engagementKey: String,
    author: String,
    content: String,
    createdAt: Date = Date(),
    isMine: Bool = false
  ) {
    self.id = id
    self.engagementKey = engagementKey
    self.author = author
    self.content = content
    self.createdAt = createdAt
    self.isMine = isMine
  }

  private enum CodingKeys: String, CodingKey {
    case id, engagementKey, imageId, author, content, createdAt, isMine
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    author = try container.decode(String.self, forKey: .author)
    content = try container.decode(String.self, forKey: .content)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    isMine = try container.decodeIfPresent(Bool.self, forKey: .isMine) ?? false
    if let key = try container.decodeIfPresent(String.self, forKey: .engagementKey), !key.isEmpty {
      engagementKey = key
    } else if let legacyId = try container.decodeIfPresent(Int.self, forKey: .imageId) {
      engagementKey = EngagementKeyMigration.fromLegacyImageID(legacyId)
    } else {
      engagementKey = ""
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(engagementKey, forKey: .engagementKey)
    try container.encode(author, forKey: .author)
    try container.encode(content, forKey: .content)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(isMine, forKey: .isMine)
  }
}

private enum EngagementKeyMigration {
  static func fromLegacyImageID(_ id: Int) -> String {
    id >= 10_000 ? "user-\(id)" : "sample-\(id)"
  }
}

private struct StoredEngagement: Codable {
  var storageVersion: Int?
  var likedKeys: [String]?
  var favoritedKeys: [String]?
  var likedImageIDs: [Int]?
  var favoritedImageIDs: [Int]?
  var comments: [ImageCommentRecord]
  var didSeedSampleComments: Bool
}

@MainActor
final class ImageEngagementStore: ObservableObject {
  static let shared = ImageEngagementStore()

  @Published private(set) var likedKeys: Set<String> = []
  @Published private(set) var favoritedKeys: Set<String> = []
  @Published private(set) var commentsByEngagementKey: [String: [ImageCommentRecord]] = [:]

  private let storageKey = "imageEngagementData"
  private let currentStorageVersion = 2

  private init() {
    loadFromDisk()
  }

  func baseLikeCount(for engagementKey: String) -> Int {
    guard !engagementKey.isEmpty else { return 0 }
    let seed = stableNumericHash(engagementKey)
    return 800 + (seed % 900)
  }

  func baseFavoriteCount(for engagementKey: String) -> Int {
    guard !engagementKey.isEmpty else { return 0 }
    let seed = stableNumericHash(engagementKey)
    return 300 + (seed % 500)
  }

  func likeCount(for engagementKey: String) -> Int {
    guard !engagementKey.isEmpty else { return 0 }
    return baseLikeCount(for: engagementKey) + (likedKeys.contains(engagementKey) ? 1 : 0)
  }

  func favoriteCount(for engagementKey: String) -> Int {
    guard !engagementKey.isEmpty else { return 0 }
    return baseFavoriteCount(for: engagementKey) + (favoritedKeys.contains(engagementKey) ? 1 : 0)
  }

  func commentCount(for engagementKey: String) -> Int {
    comments(for: engagementKey).count
  }

  func isLiked(_ engagementKey: String) -> Bool {
    guard !engagementKey.isEmpty else { return false }
    return likedKeys.contains(engagementKey)
  }

  func isFavorited(_ engagementKey: String) -> Bool {
    guard !engagementKey.isEmpty else { return false }
    return favoritedKeys.contains(engagementKey)
  }

  func comments(for engagementKey: String) -> [ImageCommentRecord] {
    guard !engagementKey.isEmpty else { return [] }
    return commentsByEngagementKey[engagementKey] ?? []
  }

  @discardableResult
  func toggleLike(for engagementKey: String) -> Bool {
    guard !engagementKey.isEmpty else { return false }
    var updated = likedKeys
    let willLike: Bool
    if updated.contains(engagementKey) {
      updated.remove(engagementKey)
      willLike = false
    } else {
      updated.insert(engagementKey)
      willLike = true
    }
    likedKeys = updated
    persist()
    if willLike {
      ActivityStore.shared.record(.likeAdded())
    }
    return willLike
  }

  @discardableResult
  func toggleFavorite(for engagementKey: String) -> Bool {
    guard !engagementKey.isEmpty else { return false }
    var updated = favoritedKeys
    let willFavorite: Bool
    if updated.contains(engagementKey) {
      updated.remove(engagementKey)
      willFavorite = false
    } else {
      updated.insert(engagementKey)
      willFavorite = true
    }
    favoritedKeys = updated
    persist()
    if willFavorite {
      ActivityStore.shared.record(.favoriteAdded())
    }
    return willFavorite
  }

  func addComment(engagementKey: String, author: String, content: String) {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !engagementKey.isEmpty else { return }

    let record = ImageCommentRecord(
      engagementKey: engagementKey,
      author: author,
      content: trimmed,
      isMine: true
    )
    var byKey = commentsByEngagementKey
    var list = byKey[engagementKey] ?? []
    list.insert(record, at: 0)
    byKey[engagementKey] = list
    commentsByEngagementKey = byKey
    persist()
    ActivityStore.shared.record(.commentPosted())
  }

  private func loadFromDisk() {
    guard let stored = StoredEngagement.load(from: storageKey) else {
      seedSampleCommentsIfNeeded()
      return
    }

    let needsLegacyMigration = (stored.storageVersion ?? 1) < currentStorageVersion

    likedKeys = Set(stored.likedKeys ?? stored.likedImageIDs?.map(EngagementKeyMigration.fromLegacyImageID) ?? [])
    favoritedKeys = Set(
      stored.favoritedKeys ?? stored.favoritedImageIDs?.map(EngagementKeyMigration.fromLegacyImageID) ?? []
    )

    let loadedComments = stored.comments.filter { !$0.engagementKey.isEmpty }
    commentsByEngagementKey = Dictionary(grouping: loadedComments, by: \.engagementKey)
      .mapValues { $0.sorted { $0.createdAt > $1.createdAt } }

    if needsLegacyMigration || !stored.didSeedSampleComments {
      seedSampleCommentsIfNeeded(forceReseed: needsLegacyMigration)
    } else if commentsByEngagementKey.isEmpty {
      seedSampleCommentsIfNeeded()
    } else {
      seedMissingSampleComments()
      persist()
    }
  }

  private static let sampleCommentsByEngagementKey: [String: [(String, String)]] = [
    "sample-1": [
      ("摄影爱好者", "城市天际线的构图很棒，黄昏倒影很有层次。"),
      ("旅行者", "请问这是在东城区哪段河岸拍的？"),
      ("设计师", "河面反光处理得很干净，已收藏。")
    ],
    "sample-2": [
      ("海边控", "海岸线的浪花质感很真实。"),
      ("路人甲", "这张很适合做旅行封面。")
    ],
    "sample-3": [
      ("徒步者", "森林小径的氛围感绝了，光影很治愈。")
    ],
    "sample-4": [
      ("风光党", "雪山的冷色调太震撼了。"),
      ("登山客", "云海层次拍得很清楚，想去昌平看看。")
    ],
    "sample-5": [
      ("沙漠旅人", "金色沙丘的线条很有纵深感。"),
      ("地理迷", "地平线处理得特别干净。")
    ],
    "sample-6": [
      ("湖畔摄影", "湖面倒影像镜子一样。"),
      ("慢快门", "远山和天空的色彩过渡很舒服。")
    ],
    "sample-7": [
      ("街拍君", "雨后霓虹的色调很有电影感。"),
      ("城市漫步", "行人剪影让画面更有故事感。"),
      ("西城土著", "这条街晚上更有味道。")
    ],
    "sample-8": [
      ("结构控", "桥梁钢结构的线条非常硬朗。"),
      ("工程人", "这个角度把跨度拍得很完整。")
    ],
    "sample-9": [
      ("春日记录", "花田的柔光太适合当壁纸了。"),
      ("植物爱好者", "色彩很春天，想问问具体拍摄时间。")
    ]
  ]

  private func seedSampleCommentsIfNeeded(forceReseed: Bool = false) {
    var byKey = commentsByEngagementKey
    for (engagementKey, entries) in Self.sampleCommentsByEngagementKey {
      if !forceReseed, byKey[engagementKey]?.isEmpty == false { continue }
      byKey[engagementKey] = makeCommentRecords(engagementKey: engagementKey, entries: entries)
    }
    commentsByEngagementKey = byKey
    persist(didSeedSampleComments: true)
  }

  private func seedMissingSampleComments() {
    var byKey = commentsByEngagementKey
    var didChange = false

    for (engagementKey, entries) in Self.sampleCommentsByEngagementKey {
      guard byKey[engagementKey]?.isEmpty != false else { continue }
      byKey[engagementKey] = makeCommentRecords(engagementKey: engagementKey, entries: entries)
      didChange = true
    }

    if didChange {
      commentsByEngagementKey = byKey
    }
  }

  private func makeCommentRecords(
    engagementKey: String,
    entries: [(String, String)]
  ) -> [ImageCommentRecord] {
    entries.enumerated().map { index, entry in
      ImageCommentRecord(
        engagementKey: engagementKey,
        author: entry.0,
        content: entry.1,
        createdAt: Date().addingTimeInterval(-Double((index + 1) * 3600)),
        isMine: false
      )
    }
  }

  private func persist(didSeedSampleComments: Bool? = nil) {
    let allComments = commentsByEngagementKey.values.flatMap { $0 }
      .sorted { $0.createdAt > $1.createdAt }
    let stored = StoredEngagement(
      storageVersion: currentStorageVersion,
      likedKeys: Array(likedKeys),
      favoritedKeys: Array(favoritedKeys),
      likedImageIDs: nil,
      favoritedImageIDs: nil,
      comments: allComments,
      didSeedSampleComments: didSeedSampleComments ?? (StoredEngagement.load(from: storageKey)?.didSeedSampleComments ?? false)
    )
    stored.save(to: storageKey)
  }

  private func stableNumericHash(_ string: String) -> Int {
    var hash = 0
    for byte in string.utf8 {
      hash = hash &* 31 &+ Int(byte)
    }
    return abs(hash)
  }
}

private extension StoredEngagement {
  static func load(from key: String) -> StoredEngagement? {
    guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(StoredEngagement.self, from: data)
  }

  func save(to key: String) {
    guard let data = try? JSONEncoder().encode(self) else { return }
    UserDefaults.standard.set(data, forKey: key)
  }
}
