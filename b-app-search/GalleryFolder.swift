//
//  GalleryFolder.swift
//  b-app-search
//

import Foundation

struct GalleryFolder: Identifiable, Codable, Hashable {
  let id: String
  var name: String
  var iconName: String
  let isSystem: Bool

  static let allId = "all"
  static let sharedId = "shared"
  static let uncategorizedId = "uncategorized"
  static let landscapeId = "landscape"
  static let urbanId = "urban"
  static let architectureId = "architecture"
  static let cultureId = "culture"

  /// 虚拟「全部」文件夹，仅用于筛选，不可作为图片归属。
  static let all = GalleryFolder(
    id: allId,
    name: "全部",
    iconName: "square.grid.2x2",
    isSystem: true
  )

  static let defaultSystemFolders: [GalleryFolder] = [
    GalleryFolder(id: sharedId, name: "network", iconName: "square.and.arrow.up", isSystem: true),
    GalleryFolder(id: uncategorizedId, name: "未分类", iconName: "tray", isSystem: true),
    GalleryFolder(id: landscapeId, name: "风景", iconName: "leaf.fill", isSystem: true),
    GalleryFolder(id: urbanId, name: "城市", iconName: "building.2.fill", isSystem: true),
    GalleryFolder(id: architectureId, name: "建筑", iconName: "building.columns.fill", isSystem: true),
    GalleryFolder(id: cultureId, name: "街拍", iconName: "person.2.fill", isSystem: true)
  ]

  static func defaultFolderId(forSample category: GalleryImageCategory, tag: String) -> String {
    _ = category
    _ = tag
    return sharedId
  }
}
