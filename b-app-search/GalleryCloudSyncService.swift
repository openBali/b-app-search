//
//  GalleryCloudSyncService.swift
//  b-app-search
//
//  已迁移至 BackendAPI.Gallery，保留类型别名以兼容旧代码。
//

import Foundation

typealias GalleryCloudSyncService = BackendAPI.Gallery

extension BackendAPI.Gallery {
  /// 兼容 `GalleryCloudSyncService.uploadImages` 调用。
  static func uploadImages(_ images: [GalleryImage]) async throws -> [UploadResponse] {
    try await batchUpload(images)
  }
}
