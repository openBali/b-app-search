//
//  UserAvatarView.swift
//  b-app-search
//

import SwiftUI
import UIKit

struct UserAvatarView: View {
  var name: String = ""
  var imageURL: URL?
  var size: CGFloat = 36
  var useSessionAvatar: Bool = false

  private var resolvedURL: URL? {
    if useSessionAvatar {
      return UserSession.avatarURL
    }
    return imageURL
  }

  private var displayName: String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "用户" : trimmed
  }

  private var initials: String {
    String(displayName.prefix(1)).uppercased()
  }

  var body: some View {
    Group {
      if let resolvedURL, let uiImage = UIImage(contentsOfFile: resolvedURL.path) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()
      } else {
        ZStack {
          Circle()
            .fill(fallbackColor)
          Text(initials)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(.white)
        }
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .overlay {
      Circle()
        .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
    }
  }

  private var fallbackColor: Color {
    Self.accentColor(for: displayName)
  }

  static func accentColor(for name: String) -> Color {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let displayName = trimmed.isEmpty ? "用户" : trimmed
    let palette: [Color] = [
      Color(red: 0.28, green: 0.48, blue: 0.98),
      Color(red: 0.22, green: 0.72, blue: 0.52),
      Color(red: 0.92, green: 0.28, blue: 0.32),
      Color(red: 0.95, green: 0.55, blue: 0.12),
      Color(red: 0.55, green: 0.34, blue: 0.95)
    ]
    let hash = abs(displayName.hashValue)
    return palette[hash % palette.count]
  }
}

struct UserAvatarView_Previews: PreviewProvider {
  static var previews: some View {
    HStack(spacing: 12) {
      UserAvatarView(name: "摄影爱好者", size: 44)
      UserAvatarView(name: "我", size: 44, useSessionAvatar: true)
    }
    .padding()
  }
}
