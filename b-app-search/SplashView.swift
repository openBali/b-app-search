//
//  SplashView.swift
//  b-app-search
//
//  首次安装欢迎页：默认居中展示一张图，点击后进入应用。
//

import SwiftUI

struct SplashView: View {
  var onContinue: () -> Void

  /// Asset Catalog 中的闪屏图名称，可替换 `SplashImage.imageset`。
  static let imageName = "SplashImage"
  /// 暂定 App 名称；后续可改。
  static let appDisplayName = "Photo"
  /// 底部为提示预留的比例空间。
  private let bottomReserveRatio: CGFloat = 0.10

  var body: some View {
    GeometryReader { geo in
      let bottomReserve = max(geo.size.height * bottomReserveRatio, 72)

      ZStack {
        Color(.systemBackground)
          .ignoresSafeArea()

        VStack(spacing: 0) {
          Image(Self.imageName)
            .resizable()
            .scaledToFill()
            .frame(width: geo.size.width, height: geo.size.height - bottomReserve)
            .clipped()

          Color(.systemBackground)
            .frame(height: bottomReserve)
        }
        .ignoresSafeArea(edges: .top)

        brandMark

        VStack {
          Spacer()
          nextPageHint
            .padding(.bottom, max(geo.safeAreaInsets.bottom, 8) + 10)
        }
      }
    }
    .contentShape(Rectangle())
    .onTapGesture(perform: onContinue)
    .accessibilityElement(children: .ignore)
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel("\(Self.appDisplayName)，进入应用")
    .accessibilityHint("点击继续到下一页")
  }

  private var brandMark: some View {
    VStack(spacing: 14) {
      Image(systemName: "photo.fill")
        .font(.system(size: 44, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 96, height: 96)
        .background(
          LinearGradient(
            colors: [
              Color(red: 0.28, green: 0.52, blue: 0.98),
              Color(red: 0.45, green: 0.36, blue: 0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)

      Text(Self.appDisplayName)
        .font(.system(size: 34, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
    }
  }

  private var nextPageHint: some View {
    HStack(spacing: 6) {
      Image(systemName: "hand.tap.fill")
        .font(.caption2.weight(.semibold))

      Text("轻触进入下一页")
        .font(.caption2.weight(.medium))

      Image(systemName: "chevron.right")
        .font(.system(size: 8, weight: .bold))
    }
    .foregroundStyle(.secondary)
    .padding(.horizontal, 12)
    .padding(.vertical, 7)
    .background(.ultraThinMaterial, in: Capsule())
    .overlay {
      Capsule()
        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
    }
  }
}

#if DEBUG
struct SplashView_Previews: PreviewProvider {
  static var previews: some View {
    SplashView(onContinue: {})
  }
}
#endif
