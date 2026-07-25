//
//  IOSPhotoLibrarySyncService.swift
//  b-app-search
//

import Foundation
import Photos
import UIKit

enum IOSPhotoLibrarySyncError: LocalizedError {
  case accessDenied
  case imageDataUnavailable
  case albumCreationFailed

  var errorDescription: String? {
    switch self {
    case .accessDenied:
      return "未获得相册访问权限，请在系统设置中允许访问照片。"
    case .imageDataUnavailable:
      return "无法读取图片文件。"
    case .albumCreationFailed:
      return "无法在相册中创建文件夹。"
    }
  }
}

@MainActor
final class IOSPhotoLibrarySyncService {
  static let shared = IOSPhotoLibrarySyncService()

  private let albumPrefix = "b-app-search"
  private let syncedAssetsStorageKey = "iosPhotoLibrarySyncedAssetIDs"

  private init() {}

  func requestAuthorizationIfNeeded() async throws {
    let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    switch status {
    case .authorized, .limited:
      return
    case .notDetermined:
      let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
      guard newStatus == .authorized || newStatus == .limited else {
        throw IOSPhotoLibrarySyncError.accessDenied
      }
    default:
      throw IOSPhotoLibrarySyncError.accessDenied
    }
  }

  func syncAll(from galleryStore: GalleryStore) async throws {
    guard AppSettings.isIOSPhotoLibrarySyncActive else { return }
    try await requestAuthorizationIfNeeded()

    for image in galleryStore.userImages where image.url.isFileURL {
      let folderId = galleryStore.resolvedFolderId(for: image)
      guard let folder = galleryStore.folder(for: folderId) else { continue }
      try await ensureImageInFolderAlbum(image, folderName: folder.name)
    }
  }

  func ensureImageInFolderAlbum(_ image: GalleryImage, folderName: String) async throws {
    guard AppSettings.isIOSPhotoLibrarySyncActive else { return }
    guard image.url.isFileURL else { return }
    try await requestAuthorizationIfNeeded()

    let albumTitle = "\(albumPrefix) · \(folderName)"
    let album = try await fetchOrCreateAlbum(named: albumTitle)
    var syncedMap = loadSyncedMap()

    if
      let existingID = syncedMap[image.engagementKey],
      let asset = PHAsset.fetchAssets(withLocalIdentifiers: [existingID], options: nil).firstObject
    {
      try await addAsset(asset, to: album)
      return
    }

    let assetID = try await createAsset(from: image, in: album)
    syncedMap[image.engagementKey] = assetID
    saveSyncedMap(syncedMap)
  }

  func syncImage(_ image: GalleryImage, folderName: String) async throws {
    try await ensureImageInFolderAlbum(image, folderName: folderName)
  }

  func syncIfActive(image: GalleryImage, galleryStore: GalleryStore) {
    guard AppSettings.isIOSPhotoLibrarySyncActive else { return }
    let folderId = galleryStore.resolvedFolderId(for: image)
    guard let folder = galleryStore.folder(for: folderId) else { return }
    Task {
      try? await ensureImageInFolderAlbum(image, folderName: folder.name)
    }
  }

  func syncIfActive(galleryStore: GalleryStore) {
    guard AppSettings.isIOSPhotoLibrarySyncActive else { return }
    Task {
      try? await syncAll(from: galleryStore)
    }
  }

  // MARK: - Private

  private func saveImageToAlbum(image: GalleryImage, folderName: String) async throws -> String {
    let albumTitle = "\(albumPrefix) · \(folderName)"
    let album = try await fetchOrCreateAlbum(named: albumTitle)
    return try await createAsset(from: image, in: album)
  }

  private func createAsset(from image: GalleryImage, in album: PHAssetCollection) async throws -> String {
    guard let data = try? Data(contentsOf: image.url), let uiImage = UIImage(data: data) else {
      throw IOSPhotoLibrarySyncError.imageDataUnavailable
    }
    return try await createAsset(from: uiImage, in: album)
  }

  private func addAsset(_ asset: PHAsset, to album: PHAssetCollection) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      PHPhotoLibrary.shared().performChanges {
        guard let request = PHAssetCollectionChangeRequest(for: album) else { return }
        request.addAssets([asset] as NSArray)
      } completionHandler: { success, error in
        if let error {
          continuation.resume(throwing: error)
        } else if success {
          continuation.resume(returning: ())
        } else {
          continuation.resume(throwing: IOSPhotoLibrarySyncError.albumCreationFailed)
        }
      }
    }
  }

  private func fetchOrCreateAlbum(named title: String) async throws -> PHAssetCollection {
    if let existing = fetchAlbum(named: title) {
      return existing
    }
    return try await withCheckedThrowingContinuation { continuation in
      var placeholder: PHObjectPlaceholder?
      PHPhotoLibrary.shared().performChanges {
        let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
        placeholder = request.placeholderForCreatedAssetCollection
      } completionHandler: { success, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        guard success, let placeholder, let collection = PHAssetCollection.fetchAssetCollections(
          withLocalIdentifiers: [placeholder.localIdentifier],
          options: nil
        ).firstObject else {
          continuation.resume(throwing: IOSPhotoLibrarySyncError.albumCreationFailed)
          return
        }
        continuation.resume(returning: collection)
      }
    }
  }

  private func fetchAlbum(named title: String) -> PHAssetCollection? {
    let options = PHFetchOptions()
    options.predicate = NSPredicate(format: "title = %@", title)
    return PHAssetCollection.fetchAssetCollections(
      with: .album,
      subtype: .any,
      options: options
    ).firstObject
  }

  private func createAsset(from image: UIImage, in album: PHAssetCollection) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      var assetPlaceholder: PHObjectPlaceholder?
      PHPhotoLibrary.shared().performChanges {
        let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
        assetPlaceholder = creationRequest.placeholderForCreatedAsset
        guard
          let albumChange = PHAssetCollectionChangeRequest(for: album),
          let placeholder = assetPlaceholder
        else { return }
        albumChange.addAssets([placeholder] as NSArray)
      } completionHandler: { success, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        guard success, let assetPlaceholder else {
          continuation.resume(throwing: IOSPhotoLibrarySyncError.albumCreationFailed)
          return
        }
        continuation.resume(returning: assetPlaceholder.localIdentifier)
      }
    }
  }

  private func loadSyncedMap() -> [String: String] {
    guard
      let data = UserDefaults.standard.data(forKey: syncedAssetsStorageKey),
      let map = try? JSONDecoder().decode([String: String].self, from: data)
    else { return [:] }
    return map
  }

  private func saveSyncedMap(_ map: [String: String]) {
    guard let data = try? JSONEncoder().encode(map) else { return }
    UserDefaults.standard.set(data, forKey: syncedAssetsStorageKey)
  }
}
