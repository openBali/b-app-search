//
//  ImageTagStore.swift
//  b-app-search
//

import Foundation
import SwiftUI

@MainActor
final class ImageTagStore: ObservableObject {
  static let shared = ImageTagStore()

  @Published private(set) var remoteTags: [String] = []
  @Published var localTags: [String] = []
  @Published private(set) var isLoadingRemote = false
  @Published private(set) var isSavingLocal = false
  @Published private(set) var lastRemoteSyncAt: Date?
  @Published private(set) var lastErrorMessage: String?

  private let localTagsKey = "imageTagStore.localTags"
  private let remoteTagsCacheKey = "imageTagStore.remoteTags"
  private let remoteSyncAtKey = "imageTagStore.remoteSyncAt"

  private init() {
    loadPersistedData()
    Task { await fetchRemoteTags() }
  }

  /// 内置默认标签（不可在设置中删除）
  static let defaultTags = HomeImageFilterTags.all

  /// 合并默认、本地自定义、云端与图片中出现的标签。
  func mergedTags(extraFromImages: [String] = []) -> [String] {
    mergeUnique(
      Self.defaultTags,
      localTags,
      remoteTags,
      extraFromImages
    )
  }

  func fetchRemoteTags() async {
    guard !isLoadingRemote else { return }
    isLoadingRemote = true
    lastErrorMessage = nil
    defer { isLoadingRemote = false }

    do {
      let tags = try await BackendAPI.Tags.fetchImageTags()
      remoteTags = tags
      lastRemoteSyncAt = Date()
      persistRemoteCache()
    } catch {
      lastErrorMessage = error.localizedDescription
    }
  }

  func saveLocalTagsToServer() async {
    guard !isSavingLocal else { return }
    isSavingLocal = true
    lastErrorMessage = nil
    defer { isSavingLocal = false }

    do {
      try await BackendAPI.Tags.saveUserTags(localTags)
    } catch {
      lastErrorMessage = error.localizedDescription
    }
  }

  func addLocalTag(_ raw: String) -> Bool {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    guard !containsTag(trimmed) else { return false }
    localTags.append(trimmed)
    persistLocalTags()
    return true
  }

  func removeLocalTag(at offsets: IndexSet) {
    localTags.remove(atOffsets: offsets)
    persistLocalTags()
  }

  func removeLocalTag(_ tag: String) {
    localTags.removeAll { $0 == tag }
    persistLocalTags()
  }

  func moveLocalTags(from source: IndexSet, to destination: Int) {
    localTags.move(fromOffsets: source, toOffset: destination)
    persistLocalTags()
  }

  private func containsTag(_ tag: String) -> Bool {
    let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
    return mergedTags().contains { $0.compare(normalized, options: .caseInsensitive) == .orderedSame }
  }

  private func mergeUnique(_ groups: [String]...) -> [String] {
    var seen = Set<String>()
    var result: [String] = []

    for group in groups {
      for tag in group {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }
        let key = trimmed.lowercased()
        guard seen.insert(key).inserted else { continue }
        result.append(trimmed)
      }
    }

    return result
  }

  private func loadPersistedData() {
    if let saved = UserDefaults.standard.stringArray(forKey: localTagsKey) {
      localTags = saved
    }

    if let cached = UserDefaults.standard.stringArray(forKey: remoteTagsCacheKey) {
      remoteTags = cached
    }

    if let timestamp = UserDefaults.standard.object(forKey: remoteSyncAtKey) as? Date {
      lastRemoteSyncAt = timestamp
    }
  }

  private func persistLocalTags() {
    UserDefaults.standard.set(localTags, forKey: localTagsKey)
  }

  private func persistRemoteCache() {
    UserDefaults.standard.set(remoteTags, forKey: remoteTagsCacheKey)
    if let lastRemoteSyncAt {
      UserDefaults.standard.set(lastRemoteSyncAt, forKey: remoteSyncAtKey)
    }
  }
}
