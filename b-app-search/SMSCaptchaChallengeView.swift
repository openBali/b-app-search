//
//  SMSCaptchaChallengeView.swift
//  b-app-search
//

import SwiftUI
import UIKit

struct SMSCaptchaChallengeView: View {
  let onVerified: () -> Void
  let onCancel: () -> Void

  @State private var statusMessage: String?
  @State private var isVerified = false
  @State private var resetToken = 0

  private let puzzleHeight: CGFloat = 168

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 18) {
        Text("请完成安全验证后再发送验证码，以防止恶意请求。")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        PuzzleVerifyRepresentable(
          resetToken: resetToken,
          onVerified: handleVerified,
          onFailed: handleFailed,
          onLocked: handleLocked
        )
        .frame(height: puzzleHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        Text(isVerified ? "验证通过" : "拖动拼图块完成验证")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(isVerified ? Color.green : .secondary)
          .frame(maxWidth: .infinity)

        if let message = statusMessage {
          Text(message)
            .font(.caption)
            .foregroundStyle(isVerified ? .green : .red)
        }
      }
      .padding(20)
      .navigationTitle("安全验证")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消", action: onCancel)
        }
        ToolbarItem(placement: .primaryAction) {
          Button {
            statusMessage = nil
            isVerified = false
            resetToken += 1
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .accessibilityLabel("刷新验证")
          .disabled(isVerified)
        }
      }
    }
    .presentationDetents([.height(360)])
    .presentationDragIndicator(.visible)
  }

  private func handleVerified() {
    guard !isVerified else { return }
    isVerified = true
    statusMessage = "验证通过"
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
      onVerified()
    }
  }

  private func handleFailed() {
    guard !isVerified else { return }
    statusMessage = "拼图位置不正确，请重试"
  }

  private func handleLocked() {
    guard !isVerified else { return }
    statusMessage = "尝试次数过多，请点击右上角刷新后重试"
  }
}

// MARK: - TTGPuzzleVerify bridge

private struct PuzzleVerifyRepresentable: UIViewRepresentable {
  var resetToken: Int
  var onVerified: () -> Void
  var onFailed: () -> Void
  var onLocked: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onVerified: onVerified, onFailed: onFailed, onLocked: onLocked)
  }

  func makeUIView(context: Context) -> PuzzleVerifyHostView {
    let host = PuzzleVerifyHostView()
    host.onVerified = { [weak coordinator = context.coordinator] in
      coordinator?.onVerified()
    }
    host.onFailed = { [weak coordinator = context.coordinator] in
      coordinator?.onFailed()
    }
    host.onLocked = { [weak coordinator = context.coordinator] in
      coordinator?.onLocked()
    }
    host.reloadChallenge()
    return host
  }

  func updateUIView(_ uiView: PuzzleVerifyHostView, context: Context) {
    context.coordinator.onVerified = onVerified
    context.coordinator.onFailed = onFailed
    context.coordinator.onLocked = onLocked

    uiView.onVerified = { [weak coordinator = context.coordinator] in
      coordinator?.onVerified()
    }
    uiView.onFailed = { [weak coordinator = context.coordinator] in
      coordinator?.onFailed()
    }
    uiView.onLocked = { [weak coordinator = context.coordinator] in
      coordinator?.onLocked()
    }

    if context.coordinator.resetToken != resetToken {
      context.coordinator.resetToken = resetToken
      uiView.reloadChallenge()
    }
  }

  final class Coordinator {
    var onVerified: () -> Void
    var onFailed: () -> Void
    var onLocked: () -> Void
    var resetToken = -1

    init(onVerified: @escaping () -> Void, onFailed: @escaping () -> Void, onLocked: @escaping () -> Void) {
      self.onVerified = onVerified
      self.onFailed = onFailed
      self.onLocked = onLocked
    }
  }
}

private final class PuzzleVerifyHostView: UIView {
  var onVerified: (() -> Void)?
  var onFailed: (() -> Void)?
  var onLocked: (() -> Void)?

  private let puzzleView = TTGPuzzleVerifyView()
  private let puzzleSize = CGSize(width: 56, height: 56)
  private var pendingLayout = true

  override init(frame: CGRect) {
    super.init(frame: frame)
    puzzleView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(puzzleView)
    NSLayoutConstraint.activate([
      puzzleView.leadingAnchor.constraint(equalTo: leadingAnchor),
      puzzleView.trailingAnchor.constraint(equalTo: trailingAnchor),
      puzzleView.topAnchor.constraint(equalTo: topAnchor),
      puzzleView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard pendingLayout, bounds.width > 1, bounds.height > 1 else { return }
    pendingLayout = false
    applyChallengeLayout()
  }

  func reloadChallenge() {
    pendingLayout = true
    applyConfiguration()
    puzzleView.image = AppSkinImageSlot.captchaBackground.uiImage(
      for: AppSettings.skin,
      size: CGSize(width: 720, height: 336)
    )
    setNeedsLayout()
    layoutIfNeeded()
    if bounds.width > 1, bounds.height > 1 {
      pendingLayout = false
      applyChallengeLayout()
    }
  }

  private func applyConfiguration() {
    let configuration = TTGPuzzleVerifyConfiguration()
    configuration.puzzlePattern = .classicPattern
    configuration.puzzleSize = puzzleSize
    configuration.allowedAxes = .horizontal
    configuration.verificationTolerance = 8
    configuration.autoSnapWhenWithinTolerance = true
    configuration.recordsTrack = true
    configuration.maxRetryCount = 5
    configuration.style.cornerRadius = 12
    configuration.style.backgroundColor = .clear

    puzzleView.applyConfiguration(configuration)
    puzzleView.successAnimation = .snapAndFade
    puzzleView.failureAnimation = .shakeAndReset
    puzzleView.resetOnFailure = true

    puzzleView.completionBlock = { [weak self] _, _ in
      self?.onVerified?()
    }
    puzzleView.failureBlock = { [weak self] view, _ in
      if view.state == .locked {
        self?.onLocked?()
      } else {
        self?.onFailed?()
      }
    }
    puzzleView.stateChangeBlock = { [weak self] view, state in
      if state == .locked {
        self?.onLocked?()
      }
    }
  }

  private func applyChallengeLayout() {
    puzzleView.puzzleBlankPosition = PuzzleCaptchaBackground.randomBlankPosition(
      in: bounds.size,
      puzzleSize: puzzleSize
    )
    puzzleView.resetVerification()
  }
}

private enum PuzzleCaptchaBackground {
  static func randomBlankPosition(in size: CGSize, puzzleSize: CGSize) -> CGPoint {
    let insetX: CGFloat = 16
    let minX = max(size.width * 0.34, insetX)
    let maxX = max(minX, size.width - puzzleSize.width - insetX)
    let minY: CGFloat = 12
    let maxY = max(minY, size.height - puzzleSize.height - 12)
    return CGPoint(
      x: CGFloat.random(in: minX...maxX),
      y: CGFloat.random(in: minY...maxY)
    )
  }
}

struct SMSCaptchaChallengeView_Previews: PreviewProvider {
  static var previews: some View {
    SMSCaptchaChallengeView(onVerified: {}, onCancel: {})
  }
}
