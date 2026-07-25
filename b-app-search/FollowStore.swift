//
//  FollowStore.swift
//  b-app-search
//

import Foundation

@MainActor
final class FollowStore: ObservableObject {
  static let shared = FollowStore()

  @Published private(set) var followedProfileIds: Set<String> = []

  private let storageKey = "followedPublicProfileIds"

  private init() {
    load()
  }

  func isFollowing(_ identity: PublicProfileIdentity) -> Bool {
    followedProfileIds.contains(identity.id)
  }

  func toggleFollow(_ identity: PublicProfileIdentity) {
    guard !identity.isCurrentUser else { return }
    if followedProfileIds.contains(identity.id) {
      followedProfileIds.remove(identity.id)
    } else {
      followedProfileIds.insert(identity.id)
    }
    persist()
  }

  private func load() {
    if let stored = UserDefaults.standard.array(forKey: storageKey) as? [String] {
      followedProfileIds = Set(stored)
    }
  }

  private func persist() {
    UserDefaults.standard.set(Array(followedProfileIds), forKey: storageKey)
  }
}
