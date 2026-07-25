//
//  ImageCommentsChatView.swift
//  b-app-search
//

import SwiftUI

struct ImageCommentsChatView: View {
  let image: GalleryImage

  @EnvironmentObject private var engagementStore: ImageEngagementStore
  @Environment(\.dismiss) private var dismiss
  @AppStorage(UserSession.isLoggedInKey) private var isLoggedIn = false
  @AppStorage(UserSession.userNicknameKey) private var userNickname = ""

  @State private var messageDraft = ""
  @State private var showLoginRequiredAlert = false

  private let contentInset: CGFloat = 16
  private let sectionSpacing: CGFloat = 12
  private let sectionCornerRadius: CGFloat = 16

  private var currentUserName: String {
    let trimmed = userNickname.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "我" : trimmed
  }

  private var comments: [ImageCommentRecord] {
    engagementStore.comments(for: image.engagementKey)
  }

  private var chatTimeline: [ImageChatMessage] {
    comments
      .sorted { $0.createdAt < $1.createdAt }
      .map { comment in
        ImageChatMessage(
          id: comment.id,
          content: comment.content,
          isMine: comment.isMine || comment.author == currentUserName,
          authorName: comment.author,
          createdAt: comment.createdAt
        )
      }
  }

  var body: some View {
    VStack(spacing: sectionSpacing) {
      imageHeroSection
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      interactionPanel
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(.horizontal, contentInset)
    .padding(.top, 12)
    .padding(.bottom, contentInset)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color(.systemGroupedBackground))
    .navigationBarHidden(true)
    .alert("需要登录", isPresented: $showLoginRequiredAlert) {
      Button("确定", role: .cancel) {}
    } message: {
      Text("请先登录后再发送消息。")
    }
  }

  // MARK: - Image (top half)

  private var imageHeroSection: some View {
    ZStack(alignment: .topLeading) {
      GalleryThumbnailImage(url: image.url)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()

      LinearGradient(
        colors: [.black.opacity(0.35), .clear, .clear, .black.opacity(0.55)],
        startPoint: .top,
        endPoint: .bottom
      )
      .allowsHitTesting(false)

      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.title2)
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(.white.opacity(0.92))
          .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
      }
      .buttonStyle(.plain)
      .padding(.leading, 16)
      .padding(.top, 12)
      .accessibilityLabel("关闭")

      VStack(alignment: .leading, spacing: 10) {
        Spacer()

        Text(image.title)
          .font(.title3.weight(.bold))
          .foregroundStyle(.white)
          .lineLimit(2)

        HStack(spacing: 8) {
          Text(image.tag)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.22), in: Capsule())

          if image.hasLocation {
            Label(image.locationLabel, systemImage: "mappin.and.ellipse")
              .font(.caption2)
              .foregroundStyle(.white.opacity(0.9))
              .lineLimit(1)
          }
        }

        HStack(spacing: 0) {
          EngagementStatItem(
            icon: "heart.fill",
            value: "\(engagementStore.likeCount(for: image.engagementKey))",
            label: "赞",
            tint: Color(red: 0.95, green: 0.32, blue: 0.38),
            lightStyle: true
          )
          statDivider
          EngagementStatItem(
            icon: "bookmark.fill",
            value: "\(engagementStore.favoriteCount(for: image.engagementKey))",
            label: "收藏",
            tint: Color(red: 0.95, green: 0.62, blue: 0.12),
            lightStyle: true
          )
          statDivider
          EngagementStatItem(
            icon: "bubble.left.and.bubble.right.fill",
            value: "\(chatTimeline.count)",
            label: "聊天",
            tint: .white.opacity(0.92),
            lightStyle: true
          )
        }
        .padding(.top, 4)
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .clipShape(RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous))
  }

  private var statDivider: some View {
    Rectangle()
      .fill(Color.white.opacity(0.35))
      .frame(width: 1, height: 28)
  }

  // MARK: - Chat panel (bottom half)

  private var interactionPanel: some View {
    VStack(spacing: 0) {
      chatHeader
      chatSection
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous))
    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
  }

  private var chatHeader: some View {
    HStack {
      Text("聊天")
        .font(.headline)
      Spacer()
      Text("\(chatTimeline.count) 条")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 16)
    .padding(.top, 14)
    .padding(.bottom, 8)
  }

  private var chatSection: some View {
    VStack(spacing: 0) {
      ScrollView {
        if chatTimeline.isEmpty {
          chatEmptyState
            .frame(maxWidth: .infinity)
        } else {
          LazyVStack(alignment: .leading, spacing: 14) {
            ForEach(chatTimeline) { message in
              ChatBubbleRow(
                message: message,
                currentUserName: currentUserName
              )
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      CommentInputBar(
        text: $messageDraft,
        placeholder: isLoggedIn ? "输入聊天消息…" : "登录后可聊天",
        userName: currentUserName,
        isLoggedIn: isLoggedIn,
        onSend: sendMessage,
        onRequireLogin: { showLoginRequiredAlert = true }
      )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private var chatEmptyState: some View {
    VStack(spacing: 10) {
      Image(systemName: "bubble.left.and.bubble.right")
        .font(.system(size: 36, weight: .light))
        .foregroundStyle(.tertiary)

      Text("还没有聊天")
        .font(.subheadline.weight(.semibold))
      Text("和感兴趣的人聊聊这张图")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 16)
    .padding(.vertical, 28)
  }

  // MARK: - Actions

  private func sendMessage() {
    guard isLoggedIn else {
      showLoginRequiredAlert = true
      return
    }
    let content = messageDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !content.isEmpty else { return }
    engagementStore.addComment(engagementKey: image.engagementKey, author: currentUserName, content: content)
    messageDraft = ""
  }
}

// MARK: - Components

private struct EngagementStatItem: View {
  let icon: String
  let value: String
  let label: String
  let tint: Color
  var lightStyle: Bool = false

  var body: some View {
    VStack(spacing: 4) {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .font(.caption.weight(.semibold))
        Text(value)
          .font(.subheadline.weight(.bold))
      }
      .foregroundStyle(tint)

      Text(label)
        .font(.caption2)
        .foregroundStyle(lightStyle ? .white.opacity(0.78) : .secondary)
    }
    .frame(maxWidth: .infinity)
  }
}

private struct CommentInputBar: View {
  @Binding var text: String
  let placeholder: String
  let userName: String
  let isLoggedIn: Bool
  let onSend: () -> Void
  let onRequireLogin: () -> Void

  private var canSend: Bool {
    isLoggedIn && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    VStack(spacing: 0) {
      Divider()

      HStack(alignment: .bottom, spacing: 12) {
        UserAvatarView(name: userName, size: 36, useSessionAvatar: true)

        TextField(placeholder, text: $text, axis: .vertical)
          .lineLimit(1...4)
          .font(.subheadline)
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
          .disabled(!isLoggedIn)
          .onTapGesture {
            if !isLoggedIn { onRequireLogin() }
          }

        Button(action: sendTapped) {
          Image(systemName: "paperplane.fill")
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(
              canSend ? Color(red: 0.28, green: 0.48, blue: 0.98) : Color(.systemGray4),
              in: Circle()
            )
        }
        .disabled(!canSend)
        .accessibilityLabel("发送")
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
    .background(Color(.systemBackground))
  }

  private func sendTapped() {
    guard isLoggedIn else {
      onRequireLogin()
      return
    }
    onSend()
  }
}

private struct ChatBubbleRow: View {
  let message: ImageChatMessage
  let currentUserName: String

  var body: some View {
    HStack(alignment: .bottom, spacing: 10) {
      if message.isMine {
        Spacer(minLength: 44)
      } else {
        UserAvatarView(name: message.authorName, size: 34)
      }

      VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
        if !message.isMine {
          Text(message.authorName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }

        Text(message.content)
          .font(.subheadline)
          .foregroundStyle(message.isMine ? .white : .primary)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(
            message.isMine
              ? Color(red: 0.28, green: 0.48, blue: 0.98)
              : Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
          )
          .frame(maxWidth: 260, alignment: message.isMine ? .trailing : .leading)
      }

      if message.isMine {
        UserAvatarView(name: currentUserName, size: 34, useSessionAvatar: true)
      } else {
        Spacer(minLength: 44)
      }
    }
    .frame(maxWidth: .infinity, alignment: message.isMine ? .trailing : .leading)
  }
}

private struct ImageChatMessage: Identifiable {
  let id: UUID
  let content: String
  let isMine: Bool
  let authorName: String
  let createdAt: Date

  init(
    id: UUID = UUID(),
    content: String,
    isMine: Bool,
    authorName: String,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.content = content
    self.isMine = isMine
    self.authorName = authorName
    self.createdAt = createdAt
  }
}

struct ImageCommentsChatView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      ImageCommentsChatView(image: GalleryImage.samples[7])
        .environmentObject(ImageEngagementStore.shared)
    }
  }
}
