//
//  GalleryStore.swift
//  b-app-search
//

import Foundation
import SwiftUI
import UIKit

private struct StoredGalleryImage: Codable {
  let id: Int
  let engagementKey: String?
  let title: String
  let tag: String
  let description: String
  let localFilename: String
  let latitude: Double
  let longitude: Double
  let locationName: String?
  let hasEmbeddedLocation: Bool?
  let categoryRaw: String
  let isPublished: Bool?
  let isCloudSynced: Bool?
  let folderId: String?
  let mediaTypeRaw: String?
  let mediaURLString: String?
}

@MainActor
final class GalleryStore: ObservableObject {
  static let shared = GalleryStore()

  @Published private(set) var userImages: [GalleryImage] = []
  @Published private(set) var folders: [GalleryFolder] = []
  @Published private(set) var isCloudSyncing = false
  @Published var personalImagesSharingEnabled: Bool {
    didSet {
      UserDefaults.standard.set(personalImagesSharingEnabled, forKey: Self.sharingEnabledKey)
    }
  }

  /// 对外可见：仅「已分享」文件夹内且已发布的用户图片 + 样例
  var publicImages: [GalleryImage] {
    sharedUserImages + GalleryImage.samples
  }

  /// 首页按文件夹浏览（含私人文件夹）
  func homeImages(inFolder folderId: String) -> [GalleryImage] {
    switch folderId {
    case GalleryFolder.allId:
      return userImages + GalleryImage.samples
    case GalleryFolder.sharedId:
      return sharedUserImages + GalleryImage.samples
    default:
      return userImages.filter { resolvedFolderId(for: $0) == folderId }
    }
  }

  /// 兼容旧调用
  func publicImages(inFolder folderId: String) -> [GalleryImage] {
    homeImages(inFolder: folderId)
  }

  var sharedUserImages: [GalleryImage] {
    guard personalImagesSharingEnabled else { return [] }
    return userImages.filter { $0.isPublished && resolvedFolderId(for: $0) == GalleryFolder.sharedId }
  }

  /// 未发布的私人图片
  var privateImages: [GalleryImage] {
    userImages.filter { !$0.isPublished }
  }

  func privateImages(inFolder folderId: String) -> [GalleryImage] {
    let pool = privateImages
    guard folderId != GalleryFolder.allId else { return pool }
    return pool.filter { privateFolderId(for: $0) == folderId }
  }

  func privateImageCount(inFolder folderId: String) -> Int {
    privateImages(inFolder: folderId).count
  }

  /// Selfie 页「全部」展示用户上传的所有图片（含已发布）；子文件夹仍只统计未发布。
  func selfieImageCount(inFolder folderId: String) -> Int {
    selfieImages(inFolder: folderId).count
  }

  func selfieImages(inFolder folderId: String) -> [GalleryImage] {
    switch folderId {
    case GalleryFolder.allId:
      return userImages
    case GalleryFolder.uncategorizedId:
      return userImages.filter {
        !$0.isPublished && privateFolderId(for: $0) == GalleryFolder.uncategorizedId
      }
    default:
      return userImages.filter {
        !$0.isPublished && privateFolderId(for: $0) == folderId
      }
    }
  }

  /// 首页私人区文件夹（不含「已分享」）
  var displayPrivateFolders: [GalleryFolder] {
    let privateFolders = folders.filter { $0.id != GalleryFolder.sharedId }
    return [GalleryFolder.all] + privateFolders
  }

  /// 设置页可管理的私人文件夹（不含「已分享」）
  var manageablePrivateFolders: [GalleryFolder] {
    folders.filter { $0.id != GalleryFolder.sharedId }
  }

  func canDeleteFolder(id: String) -> Bool {
    guard let folder = folders.first(where: { $0.id == id }) else { return false }
    return !folder.isSystem && id != GalleryFolder.sharedId
  }

  func privateFolderId(for image: GalleryImage) -> String {
    image.folderId ?? GalleryFolder.uncategorizedId
  }

  func canMoveInPrivateSection(_ image: GalleryImage) -> Bool {
    isUserImage(image) && !image.isPublished
  }

  func isSharedFolder(_ folderId: String) -> Bool {
    folderId == GalleryFolder.sharedId
  }

  /// 展示用文件夹列表：「全部」+ 文件夹（已分享固定存在）
  var displayFolders: [GalleryFolder] {
    var list = folders
    if !list.contains(where: { $0.id == GalleryFolder.sharedId }) {
      list.insert(
        GalleryFolder(id: GalleryFolder.sharedId, name: "network", iconName: "square.and.arrow.up", isSystem: true),
        at: 0
      )
    }
    return [GalleryFolder.all] + list
  }

  func resolvedFolderId(for image: GalleryImage) -> String {
    if isUserImage(image) {
      if image.isPublished { return GalleryFolder.sharedId }
      return image.folderId ?? GalleryFolder.uncategorizedId
    }
    return GalleryFolder.sharedId
  }

  func imageCount(inFolder folderId: String) -> Int {
    homeImages(inFolder: folderId).count
  }

  func folder(for id: String) -> GalleryFolder? {
    if id == GalleryFolder.allId { return GalleryFolder.all }
    return folders.first(where: { $0.id == id })
  }

  func canMoveToFolder(_ image: GalleryImage) -> Bool {
    isUserImage(image)
  }

  func moveImage(engagementKey: String, toFolderId folderId: String) {
    guard folderId != GalleryFolder.allId else { return }
    guard folderId != GalleryFolder.sharedId else { return }
    guard folders.contains(where: { $0.id == folderId }) else { return }
    guard let index = userImages.firstIndex(where: { $0.engagementKey == engagementKey }) else { return }

    var images = userImages
    images[index] = images[index].updating(isPublished: false, folderId: folderId)
    userImages = images
    persistUserImages()
    if let image = userImages.first(where: { $0.engagementKey == engagementKey }) {
      IOSPhotoLibrarySyncService.shared.syncIfActive(image: image, galleryStore: self)
    }
  }

  @discardableResult
  func addFolder(name: String) -> GalleryFolder? {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    guard !folders.contains(where: { $0.name == trimmed }) else { return nil }
    guard trimmed != "network" else { return nil }

    let folder = GalleryFolder(
      id: UUID().uuidString,
      name: trimmed,
      iconName: "folder.fill",
      isSystem: false
    )
    folders = folders + [folder]
    persistFolders()
    return folder
  }

  @discardableResult
  func renameFolder(id: String, name: String) -> Bool {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    guard id != GalleryFolder.sharedId, id != GalleryFolder.allId else { return false }
    guard trimmed != "network" else { return false }
    guard let index = folders.firstIndex(where: { $0.id == id }) else { return false }
    guard !folders.contains(where: { $0.name == trimmed && $0.id != id }) else { return false }

    folders[index].name = trimmed
    persistFolders()
    return true
  }

  func deleteFolder(id: String) {
    guard canDeleteFolder(id: id) else { return }
    folders = folders.filter { $0.id != id }
    userImages = userImages.map { image in
      image.folderId == id
        ? image.updating(folderId: GalleryFolder.uncategorizedId)
        : image
    }
    persistFolders()
    persistUserImages()
  }

  /// 兼容旧调用，等同于 publicImages
  var galleryImages: [GalleryImage] {
    publicImages
  }

  private static let sharingEnabledKey = "personalImagesSharingEnabled"
  private let storageKey = "galleryUserImages"
  private let foldersStorageKey = "galleryFolders"
  private let nextIDKey = "galleryNextUserImageID"
  private let imagesDirectory: URL

  private init() {
    personalImagesSharingEnabled = UserDefaults.standard.object(forKey: Self.sharingEnabledKey) as? Bool ?? true
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    imagesDirectory = documents.appendingPathComponent("GalleryImages", isDirectory: true)
    try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    loadFolders()
    loadUserImages()
  }

  func addImage(
    imageData: Data,
    title: String,
    tag: String,
    description: String,
    latitude: Double = 0,
    longitude: Double = 0,
    locationName: String? = nil,
    hasEmbeddedLocation: Bool = false,
    category: GalleryImageCategory? = nil
  ) throws {
    let filename = try saveImageData(imageData)
    let id = nextUserImageID()
    let image = GalleryImage(
      id: id,
      title: title,
      tag: tag,
      description: description,
      url: fileURL(for: filename),
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      hasEmbeddedLocation: hasEmbeddedLocation,
      category: category,
      isPublished: false,
      folderId: GalleryFolder.uncategorizedId
    )
    userImages = [image] + userImages
    persistUserImages()
    IOSPhotoLibrarySyncService.shared.syncIfActive(image: image, galleryStore: self)
  }

  func updateImage(_ image: GalleryImage) {
    guard let index = userImages.firstIndex(where: { $0.id == image.id }) else { return }
    var images = userImages
    images[index] = image
    userImages = images
    persistUserImages()
    IOSPhotoLibrarySyncService.shared.syncIfActive(image: images[index], galleryStore: self)
  }

  func deleteImage(_ image: GalleryImage) {
    guard let index = userImages.firstIndex(where: { $0.id == image.id }) else { return }
    removeLocalFile(for: userImages[index].url)
    var images = userImages
    images.remove(at: index)
    userImages = images
    persistUserImages()
  }

  func publishImages(ids: Set<Int>) {
    guard !ids.isEmpty else { return }
    userImages = userImages.map { image in
      ids.contains(image.id)
        ? image.updating(isPublished: true, folderId: GalleryFolder.sharedId)
        : image
    }
    persistUserImages()
  }

  func unpublishImages(ids: Set<Int>) {
    guard !ids.isEmpty else { return }
    userImages = userImages.map { image in
      ids.contains(image.id)
        ? image.updating(isPublished: false, folderId: GalleryFolder.uncategorizedId)
        : image
    }
    persistUserImages()
  }

  func syncImagesToCloud(ids: Set<Int>) async throws {
    guard !ids.isEmpty else {
      throw GalleryCloudSyncError.emptySelection
    }

    isCloudSyncing = true
    defer { isCloudSyncing = false }

    let targets = userImages.filter { ids.contains($0.id) }
    let responses = try await BackendAPI.Gallery.batchUpload(targets)
    let syncedIDs = Set(responses.map(\.imageId))
    userImages = userImages.map { image in
      syncedIDs.contains(image.id) ? image.updating(isCloudSynced: true) : image
    }
    persistUserImages()
  }

  func replaceImageFile(_ image: GalleryImage, with data: Data) throws {
    guard image.url.isFileURL else { return }
    try data.write(to: image.url, options: .atomic)
  }

  func isUserImage(_ image: GalleryImage) -> Bool {
    userImages.contains(where: { $0.id == image.id })
  }

  // MARK: - Persistence

  private func nextUserImageID() -> Int {
    let id = UserDefaults.standard.integer(forKey: nextIDKey)
    let next = id >= 10_000 ? id + 1 : 10_000
    UserDefaults.standard.set(next, forKey: nextIDKey)
    return next
  }

  private func fileURL(for filename: String) -> URL {
    imagesDirectory.appendingPathComponent(filename)
  }

  private func saveImageData(_ data: Data) throws -> String {
    let filename = UUID().uuidString + ".jpg"
    try data.write(to: fileURL(for: filename))
    return filename
  }

  private func removeLocalFile(for url: URL) {
    guard url.isFileURL else { return }
    try? FileManager.default.removeItem(at: url)
  }

  private func loadUserImages() {
    guard
      let data = UserDefaults.standard.data(forKey: storageKey),
      let records = try? JSONDecoder().decode([StoredGalleryImage].self, from: data)
    else { return }

    userImages = records.compactMap { record in
      let url = fileURL(for: record.localFilename)
      guard FileManager.default.fileExists(atPath: url.path) else { return nil }
      return GalleryImage(
        id: record.id,
        title: record.title,
        tag: record.tag,
        description: record.description,
        url: url,
        latitude: record.latitude,
        longitude: record.longitude,
        locationName: record.locationName,
        hasEmbeddedLocation: record.hasEmbeddedLocation ?? false,
        category: GalleryImageCategory(rawValue: record.categoryRaw),
        isPublished: record.isPublished ?? false,
        isCloudSynced: record.isCloudSynced ?? false,
        engagementKey: record.engagementKey,
        folderId: record.folderId,
        mediaType: GalleryMediaType.parse(record.mediaTypeRaw),
        mediaURL: record.mediaURLString.flatMap(URL.init(string:))
      )
    }
    migratePublishedImagesToSharedFolder()
  }

  private func migratePublishedImagesToSharedFolder() {
    userImages = userImages.map { image in
      guard image.isPublished, image.folderId != GalleryFolder.sharedId else { return image }
      return image.updating(folderId: GalleryFolder.sharedId)
    }
  }

  private func persistUserImages() {
    let records = userImages.compactMap { image -> StoredGalleryImage? in
      guard image.url.isFileURL else { return nil }
      return StoredGalleryImage(
        id: image.id,
        engagementKey: image.engagementKey,
        title: image.title,
        tag: image.tag,
        description: image.description,
        localFilename: image.url.lastPathComponent,
        latitude: image.latitude,
        longitude: image.longitude,
        locationName: image.locationName,
        hasEmbeddedLocation: image.hasEmbeddedLocation,
        categoryRaw: image.category.rawValue,
        isPublished: image.isPublished,
        isCloudSynced: image.isCloudSynced,
        folderId: image.folderId,
        mediaTypeRaw: image.mediaType.rawValue,
        mediaURLString: image.mediaURL?.absoluteString
      )
    }
    guard let data = try? JSONEncoder().encode(records) else { return }
    UserDefaults.standard.set(data, forKey: storageKey)
  }

  private func loadFolders() {
    if
      let data = UserDefaults.standard.data(forKey: foldersStorageKey),
      let stored = try? JSONDecoder().decode([GalleryFolder].self, from: data),
      !stored.isEmpty
    {
      folders = stored
    } else {
      folders = GalleryFolder.defaultSystemFolders
      persistFolders()
    }
    ensureSharedFolderExists()
  }

  private func ensureSharedFolderExists() {
    guard !folders.contains(where: { $0.id == GalleryFolder.sharedId }) else { return }
    folders.insert(
      GalleryFolder(id: GalleryFolder.sharedId, name: "network", iconName: "square.and.arrow.up", isSystem: true),
      at: 0
    )
    persistFolders()
  }

  private func persistFolders() {
    guard let data = try? JSONEncoder().encode(folders) else { return }
    UserDefaults.standard.set(data, forKey: foldersStorageKey)
  }
}
