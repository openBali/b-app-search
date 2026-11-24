//
//  FloatingShortcutOverlay.swift
//  b-app-search
//
//  边缘胶囊浮钮：只渲染按钮本身（无全屏层），点开用系统菜单。
//

import SwiftUI
import UIKit

struct FloatingShortcutOverlay: View {
  var onOpenHomeTab: (() -> Void)?
  var onOpenMapTab: (() -> Void)?

  @Environment(\.colorScheme) private var colorScheme

  @AppStorage(AppSettings.floatingShortcutEdgeKey) private var edgeRaw = FloatingShortcutEdge.right.rawValue
  @AppStorage(AppSettings.floatingShortcutOffsetYKey) private var offsetYRatio = 0.55

  @State private var isDragging = false
  @State private var dragTranslation: CGSize = .zero
  @State private var showActions = false
  @State private var showRideOptions = false

  private let handleWidth: CGFloat = 28
  private let handleHeight: CGFloat = 56
  /// 闲置半隐宽度（小于按钮宽，保证仍看得见）
  private let idleHideWidth: CGFloat = 10
  private let idleOpacity: Double = 0.6
  private let verticalSafePadding: CGFloat = 120

  private var edge: FloatingShortcutEdge {
    FloatingShortcutEdge(rawValue: edgeRaw) ?? .right
  }

  private var isIdleDocked: Bool {
    !isDragging && !showActions
  }

  private var handleFill: Color {
    colorScheme == .dark
      ? Color(white: 0.78).opacity(0.6)
      : Color(white: 0.94).opacity(0.95)
  }

  private var handleRing: Color {
    colorScheme == .dark
      ? Color.white.opacity(0.4)
      : Color.black.opacity(0.14)
  }

  private var gripLineColor: Color {
    colorScheme == .dark
      ? Color.white.opacity(0.75)
      : Color.primary.opacity(0.5)
  }

  private var screenSize: CGSize {
    UIScreen.main.bounds.size
  }

  /// 父级固定 trailing；左边时跨屏偏移。闲置只藏 10pt，避免被裁没。
  private var offsetX: CGFloat {
    let edgeJump = edge == .left ? -(screenSize.width - handleWidth - 8) : 0
    let hide = isIdleDocked ? (edge == .left ? -idleHideWidth : idleHideWidth) : 0
    return edgeJump + hide + dragTranslation.width
  }

  /// trailing overlay 默认垂直居中，按比例换算成相对中心的偏移。
  private var offsetY: CGFloat {
    let height = screenSize.height
    let top = verticalSafePadding * 0.35
    let bottom = max(height - verticalSafePadding - handleHeight, top)
    let travel = max(bottom - top, 1)
    let absoluteY = top + CGFloat(offsetYRatio) * travel + handleHeight / 2
    return absoluteY - height / 2 + dragTranslation.height
  }

  var body: some View {
    handleButton
      .offset(x: offsetX, y: offsetY)
      .opacity(isIdleDocked ? idleOpacity : 1)
      .animation(.easeInOut(duration: 0.22), value: isIdleDocked)
      // 往内收一点，防止被屏幕边缘裁切
      .padding(.trailing, 6)
      .confirmationDialog("快捷操作", isPresented: $showActions, titleVisibility: .visible) {
        Button("打车") { showRideOptions = true }
        Button("导航") { switchPreferredMap() }
        Button("地图") { onOpenMapTab?() }
        Button("首页") { onOpenHomeTab?() }
        Button("取消", role: .cancel) {}
      }
      .confirmationDialog("选择打车方式", isPresented: $showRideOptions, titleVisibility: .visible) {
        Button("滴滴出行") { RideHailingLauncher.openDidi() }
        Button("高德打车") { RideHailingLauncher.openAmapTaxi() }
        Button("取消", role: .cancel) {}
      }
  }

  private var handleButton: some View {
    Button {
      showActions = true
    } label: {
      ZStack {
        Capsule(style: .continuous)
          .fill(.ultraThinMaterial)
        Capsule(style: .continuous)
          .fill(handleFill)
        Capsule(style: .continuous)
          .strokeBorder(handleRing, lineWidth: 1)

        Capsule(style: .continuous)
          .fill(gripLineColor)
          .frame(width: 3, height: 22)
      }
      .frame(width: handleWidth, height: handleHeight)
      .contentShape(Capsule())
      .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("快捷操作")
    .highPriorityGesture(dockDragGesture)
  }

  private var dockDragGesture: some Gesture {
    DragGesture(minimumDistance: 6)
      .onChanged { value in
        if !isDragging {
          withAnimation(.easeOut(duration: 0.12)) { isDragging = true }
        }
        dragTranslation = value.translation
      }
      .onEnded { value in
        let width = max(screenSize.width, 1)
        let height = max(screenSize.height, 1)
        let anchorX = edge == .left ? 20 : width - 20
        let currentX = anchorX + value.translation.width
        let newEdge: FloatingShortcutEdge = currentX < width / 2 ? .left : .right

        let top = verticalSafePadding * 0.35
        let bottom = height - verticalSafePadding - handleHeight
        let travel = max(bottom - top, 1)
        let proposedY = top + CGFloat(offsetYRatio) * travel + value.translation.height
        let clamped = min(max(proposedY, top), bottom)
        let ratio = Double((clamped - top) / travel)

        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
          edgeRaw = newEdge.rawValue
          offsetYRatio = min(max(ratio, 0), 1)
          dragTranslation = .zero
          isDragging = false
        }
      }
  }

  private func switchPreferredMap() {
    let all = PreferredMapApp.allCases
    let current = AppSettings.preferredMapApp
    let nextIndex = ((all.firstIndex(of: current) ?? 0) + 1) % all.count
    let next = all[nextIndex]
    AppSettings.setPreferredMapApp(next)
    onOpenMapTab?()
  }
}

enum FloatingShortcutEdge: String {
  case left
  case right
}

enum RideHailingLauncher {
  static func openDidi() {
    open(
      appURL: URL(string: "diditaxi://"),
      webURL: URL(string: "https://www.didiglobal.com/")
    )
  }

  static func openAmapTaxi() {
    open(
      appURL: URL(string: "iosamap://ride?sourceApplication=b-app-search"),
      webURL: URL(string: "https://www.amap.com/")
    )
  }

  private static func open(appURL: URL?, webURL: URL?) {
    if let appURL, UIApplication.shared.canOpenURL(appURL) {
      UIApplication.shared.open(appURL)
    } else if let webURL {
      UIApplication.shared.open(webURL)
    }
  }
}
