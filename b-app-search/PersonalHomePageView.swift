//
//  PersonalHomePageView.swift
//  b-app-search
//

import PhotosUI
import SwiftUI

struct PersonalHomePageView: View {
  @EnvironmentObject private var galleryStore: GalleryStore
  @EnvironmentObject private var followStore: FollowStore
  @EnvironmentObject private var engagementStore: ImageEngagementStore

  let identity: PublicProfileIdentity

  @State private var selectedMediaDestination: GalleryMediaOpenDestination?
  @State private var selectedAvatarItem: PhotosPickerItem?
  @State private var avatarRefreshToken = UUID()
  @State private var avatarErrorMessage: String?

  private let horizontalInset: CGFloat = 16

  private var profile: PublicProfileSnapshot {
    PublicProfileService.snapshot(for: identity, galleryStore: galleryStore)
  }

  private var stats: ProfileStats {
    ProfileStatsService.stats(
      for: identity,
      galleryStore: galleryStore,
      engagementStore: engagementStore
    )
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        headerSection
        recentSharedSection
      }
      .padding(.bottom, 28)
    }
    .scrollContentBackground(.hidden)
    .background(Color.white)
    .navigationTitle("个人主页")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(Color.white, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .fullScreenCover(item: $selectedMediaDestination) { destination in
      GalleryMediaDestinationView(destination: destination)
    }
    .onChange(of: selectedAvatarItem) { newItem in
      guard profile.isCurrentUser, let newItem else { return }
      Task {
        if let data = try? await newItem.loadTransferable(type: Data.self) {
          do {
            _ = try await BackendAPI.User.uploadAvatar(data)
            await MainActor.run {
              avatarRefreshToken = UUID()
              selectedAvatarItem = nil
            }
          } catch {
            await MainActor.run {
              avatarErrorMessage = error.localizedDescription
            }
          }
        }
      }
    }
    .alert("头像保存失败", isPresented: avatarErrorBinding) {
      Button("确定", role: .cancel) { avatarErrorMessage = nil }
    } message: {
      Text(avatarErrorMessage ?? "")
    }
  }

  private var avatarErrorBinding: Binding<Bool> {
    Binding(
      get: { avatarErrorMessage != nil },
      set: { if !$0 { avatarErrorMessage = nil } }
    )
  }

  @ViewBuilder
  private var profileAvatar: some View {
    let avatar = UserAvatarView(
      name: profile.nickname,
      imageURL: profile.avatarURL,
      size: 88,
      useSessionAvatar: profile.usesSessionAvatar
    )
    .id(avatarRefreshToken)

    if profile.isCurrentUser {
      PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
        ZStack(alignment: .bottomTrailing) {
          avatar

          Image(systemName: "camera.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(6)
            .background(Color.black.opacity(0.55), in: Circle())
            .offset(x: 2, y: 2)
        }
      }
      .buttonStyle(.plain)
      .accessibilityLabel("更换头像")
    } else {
      avatar
    }
  }

  private var headerSection: some View {
    VStack(spacing: 16) {
      profileAvatar

      VStack(spacing: 6) {
        Text(profile.nickname)
          .font(.title2.weight(.bold))

        if let locationText = profile.locationText {
          Label(locationText, systemImage: "mappin.and.ellipse")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }

      if !profile.contactRows.isEmpty {
        contactInfoSection
      }

      if !profile.isCurrentUser {
        followButton
      }

      statsSection
      ProfileSocialShareBar(nickname: profile.nickname)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 24)
    .padding(.horizontal, horizontalInset)
  }

  private var contactInfoSection: some View {
    VStack(spacing: 8) {
      ForEach(profile.contactRows) { row in
        HStack(spacing: 8) {
          Image(systemName: row.icon)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 18)
          Text(row.title)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(row.value)
            .font(.subheadline)
            .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
      }
    }
    .padding(.vertical, 4)
  }

  private var statsSection: some View {
    HStack(spacing: 0) {
      ProfileStatCell(value: stats.likeCount, label: "点赞")
      divider
      ProfileStatCell(value: stats.shareCount, label: "分享")
      divider
      ProfileStatCell(value: stats.favoriteCount, label: "收藏")
      divider
      ProfileStatCell(value: stats.commentCount, label: "评论")
    }
    .padding(.vertical, 14)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private var divider: some View {
    Rectangle()
      .fill(Color(.separator).opacity(0.4))
      .frame(width: 1, height: 32)
  }

  private var followButton: some View {
    let isFollowing = followStore.isFollowing(identity)

    return Button {
      followStore.toggleFollow(identity)
    } label: {
      Text(isFollowing ? "Following" : "Follow me")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(isFollowing ? Color.primary : Color.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
          if isFollowing {
            Capsule()
              .strokeBorder(Color(.separator), lineWidth: 1)
              .background(Capsule().fill(Color(.tertiarySystemFill)))
          } else {
            Capsule()
              .fill(
                LinearGradient(
                  colors: [
                    Color(red: 0.28, green: 0.48, blue: 0.98),
                    Color(red: 0.42, green: 0.34, blue: 0.95)
                  ],
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
          }
        }
    }
    .buttonStyle(.plain)
    .animation(.easeInOut(duration: 0.2), value: isFollowing)
  }

  private var recentSharedSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("最近分享")
        .font(.headline)
        .padding(.horizontal, horizontalInset)

      if profile.recentSharedImages.isEmpty {
        Text(profile.isCurrentUser ? "还没有已分享的图片" : "暂无已分享图片")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 36)
          .padding(.horizontal, horizontalInset)
      } else {
        GalleryWaterfallView(
          images: profile.recentSharedImages,
          horizontalInset: horizontalInset,
          onImageTap: { selectedMediaDestination = .open($0, in: profile.recentSharedImages) },
          onSimilarGroupTap: { group in
            guard let cover = group.first else { return }
            selectedMediaDestination = .open(cover, in: group)
          }
        )
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white)
  }
}

private struct ProfileStatCell: View {
  let value: Int
  let label: String

  var body: some View {
    VStack(spacing: 4) {
      Text(formattedValue)
        .font(.headline.weight(.bold))
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }

  private var formattedValue: String {
    if value >= 10_000 {
      return String(format: "%.1f万", Double(value) / 10_000)
    }
    if value >= 1_000 {
      return String(format: "%.1fk", Double(value) / 1_000)
    }
    return "\(value)"
  }
}

struct PersonalHomePageView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      PersonalHomePageView(identity: .currentUser)
        .environmentObject(GalleryStore.shared)
        .environmentObject(FollowStore.shared)
        .environmentObject(ImageEngagementStore.shared)
    }
  }
}
