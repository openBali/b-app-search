//
//  HomeAdStore.swift
//  b-app-search
//

import Foundation
import SwiftUI

@MainActor
final class HomeAdStore: ObservableObject {
  static let shared = HomeAdStore()

  @Published private(set) var placements: [HomeAdPlacement] = []
  @Published private(set) var isLoading = false
  @Published private(set) var lastFetchedAt: Date?
  @Published private(set) var lastErrorMessage: String?

  private let cacheKey = "homeAdStore.placements"
  private let cacheTimestampKey = "homeAdStore.fetchedAt"

  private init() {
    loadCachedPlacements()
    Task { await fetchPlacements() }
  }

  func fetchPlacements() async {
    guard !isLoading else { return }
    isLoading = true
    lastErrorMessage = nil
    defer { isLoading = false }

    do {
      let items = try await BackendAPI.HomeAds.fetchPlacements()
      placements = items
      lastFetchedAt = Date()
      persistCache()
    } catch {
      lastErrorMessage = error.localizedDescription
      if placements.isEmpty {
        placements = HomeAdPlacement.mockPlacements
      }
    }
  }

  private func loadCachedPlacements() {
    guard
      let data = UserDefaults.standard.data(forKey: cacheKey),
      let cached = try? JSONDecoder().decode([HomeAdPlacement].self, from: data)
    else { return }
    placements = cached
    lastFetchedAt = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date
  }

  private func persistCache() {
    guard let data = try? JSONEncoder().encode(placements) else { return }
    UserDefaults.standard.set(data, forKey: cacheKey)
    if let lastFetchedAt {
      UserDefaults.standard.set(lastFetchedAt, forKey: cacheTimestampKey)
    }
  }
}
