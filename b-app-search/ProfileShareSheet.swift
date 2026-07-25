//
//  ProfileShareSheet.swift
//  b-app-search
//

import SwiftUI
import UIKit

enum ProfileSocialPlatform: String, CaseIterable, Identifiable {
  case instagram
  case facebook
  case x

  var id: String { rawValue }

  var title: String {
    switch self {
    case .instagram: return "Instagram"
    case .facebook: return "Facebook"
    case .x: return "X"
    }
  }

  var iconName: String {
    switch self {
    case .instagram: return "camera.fill"
    case .facebook: return "f.circle.fill"
    case .x: return "xmark"
    }
  }

  var tint: Color {
    switch self {
    case .instagram:
      return Color(red: 0.88, green: 0.19, blue: 0.42)
    case .facebook:
      return Color(red: 0.23, green: 0.35, blue: 0.95)
    case .x:
      return Color.primary
    }
  }
}

enum ProfileShareService {
  static func shareMessage(nickname: String) -> String {
    "来看看 \(nickname) 在 b-app-search 的个人主页"
  }

  @MainActor
  static func open(platform: ProfileSocialPlatform, nickname: String) {
    let message = shareMessage(nickname: nickname)
    let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? message

    let urlString: String?
    switch platform {
    case .instagram:
      urlString = "instagram://app"
    case .facebook:
      urlString = "https://www.facebook.com/sharer/sharer.php?quote=\(encoded)"
    case .x:
      urlString = "https://twitter.com/intent/tweet?text=\(encoded)"
    }

    if let urlString, let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url)
      return
    }

    presentSystemShare(message: message)
  }

  @MainActor
  private static func presentSystemShare(message: String) {
    let controller = UIActivityViewController(activityItems: [message], applicationActivities: nil)
    guard
      let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
    else { return }

    var presenter = root
    while let presented = presenter.presentedViewController {
      presenter = presented
    }
    if let popover = controller.popoverPresentationController {
      popover.sourceView = presenter.view
      popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
    }
    presenter.present(controller, animated: true)
  }
}

struct ProfileSocialShareBar: View {
  let nickname: String

  var body: some View {
    HStack(spacing: 12) {
      ForEach(ProfileSocialPlatform.allCases) { platform in
        Button {
          ProfileShareService.open(platform: platform, nickname: nickname)
        } label: {
          HStack(spacing: 6) {
            Image(systemName: platform.iconName)
              .font(.caption.weight(.bold))
            Text(platform.title)
              .font(.caption.weight(.semibold))
          }
          .foregroundStyle(platform.tint)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background(platform.tint.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
      }
    }
  }
}
