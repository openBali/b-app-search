//
//  MapFocusController.swift
//  b-app-search
//

import Foundation

/// 从首页等页面请求地图 Tab 聚焦到某张图片坐标。
@MainActor
final class MapFocusController: ObservableObject {
  @Published private(set) var focusedImageID: Int?

  func focus(on image: GalleryImage) {
    focusedImageID = image.id
  }

  func clearFocus() {
    focusedImageID = nil
  }
}
