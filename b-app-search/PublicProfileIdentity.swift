//
//  PublicProfileIdentity.swift
//  b-app-search
//

import Foundation

struct PublicProfileIdentity: Hashable, Identifiable {
  static let currentUserId = "me"
  static let currentUser = PublicProfileIdentity(id: currentUserId)

  let id: String

  var isCurrentUser: Bool {
    id == Self.currentUserId
  }

  var sampleIndex: Int? {
    guard id.hasPrefix("sample-") else { return nil }
    return Int(id.dropFirst("sample-".count))
  }

  static func sample(index: Int) -> PublicProfileIdentity {
    PublicProfileIdentity(id: "sample-\(index)")
  }
}

struct ProfileContactRow: Identifiable, Equatable {
  let id: String
  let icon: String
  let title: String
  let value: String
}

struct PublicProfileSnapshot {
  let identity: PublicProfileIdentity
  let nickname: String
  let avatarURL: URL?
  let usesSessionAvatar: Bool
  let locationText: String?
  let contactRows: [ProfileContactRow]
  let recentSharedImages: [GalleryImage]
  let isCurrentUser: Bool
}

enum PublicProfileService {
  @MainActor
  static func snapshot(
    for identity: PublicProfileIdentity,
    galleryStore: GalleryStore
  ) -> PublicProfileSnapshot {
    if identity.isCurrentUser {
      let nickname = resolvedCurrentUserNickname()
      let shareLocation = UserDefaults.standard.bool(forKey: AppSettings.shareLocationOnProfileKey)
      let locationName = UserDefaults.standard.string(forKey: AppSettings.profileLocationNameKey)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      return PublicProfileSnapshot(
        identity: identity,
        nickname: nickname,
        avatarURL: UserSession.avatarURL,
        usesSessionAvatar: true,
        locationText: shareLocation && !locationName.isEmpty ? locationName : nil,
        contactRows: currentUserContactRows(),
        recentSharedImages: Array(galleryStore.sharedUserImages.prefix(10)),
        isCurrentUser: true
      )
    }

    let index = identity.sampleIndex ?? 0
    let nickname = GalleryImage.sampleAuthorNames[
      min(index, GalleryImage.sampleAuthorNames.count - 1)
    ]
    let location = GalleryImage.sampleAuthorLocations[
      min(index, GalleryImage.sampleAuthorLocations.count - 1)
    ]
    let images = GalleryImage.samples
      .filter { $0.sampleAuthorIndex == index }
      .prefix(10)

    return PublicProfileSnapshot(
      identity: identity,
      nickname: nickname,
      avatarURL: nil,
      usesSessionAvatar: false,
      locationText: location,
      contactRows: [],
      recentSharedImages: Array(images),
      isCurrentUser: false
    )
  }

  private static func currentUserContactRows() -> [ProfileContactRow] {
    var rows: [ProfileContactRow] = []

    if UserDefaults.standard.bool(forKey: AppSettings.showEmailOnProfileKey) {
      let email = UserSession.email.trimmingCharacters(in: .whitespacesAndNewlines)
      if !email.isEmpty {
        rows.append(ProfileContactRow(id: "email", icon: "envelope.fill", title: "邮箱", value: email))
      }
    }

    if UserDefaults.standard.bool(forKey: AppSettings.showPhoneOnProfileKey) {
      let phone = UserSession.phone.trimmingCharacters(in: .whitespacesAndNewlines)
      if !phone.isEmpty {
        rows.append(ProfileContactRow(id: "phone", icon: "phone.fill", title: "电话", value: phone))
      }
    }

    if UserDefaults.standard.bool(forKey: AppSettings.showAgeOnProfileKey) {
      let age = UserSession.age.trimmingCharacters(in: .whitespacesAndNewlines)
      if !age.isEmpty {
        rows.append(ProfileContactRow(id: "age", icon: "person.fill", title: "年龄", value: age))
      }
    }

    return rows
  }

  private static func resolvedCurrentUserNickname() -> String {
    let trimmed = UserSession.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "用户" : trimmed
  }
}
