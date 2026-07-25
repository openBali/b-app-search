//
//  GalleryMediaSupport.swift
//  b-app-search
//
//  媒体类型播放：music 封面内联播控；video 独立播放页。
//

import AVFoundation
import AVKit
import Combine
import SwiftUI

// MARK: - Open routing

enum GalleryMediaOpenDestination: Identifiable {
  case photoViewer(initial: GalleryImage, images: [GalleryImage])
  case videoPlayer(GalleryImage)

  var id: String {
    switch self {
    case .photoViewer(let initial, _):
      return "photo-\(initial.engagementKey)"
    case .videoPlayer(let image):
      return "video-\(image.engagementKey)"
    }
  }

  static func open(_ image: GalleryImage, in images: [GalleryImage]) -> GalleryMediaOpenDestination {
    switch image.mediaType {
    case .video:
      return .videoPlayer(image)
    case .photo, .music:
      return .photoViewer(initial: image, images: images)
    }
  }
}

struct GalleryMediaDestinationView: View {
  let destination: GalleryMediaOpenDestination
  var onLocationTap: ((GalleryImage) -> Void)?
  var onCurrentImageChanged: ((GalleryImage) -> Void)?

  var body: some View {
    switch destination {
    case .photoViewer(let initial, let images):
      ImageViewer(
        images: images,
        initialImage: initial,
        onLocationTap: onLocationTap,
        onCurrentImageChanged: onCurrentImageChanged
      )
    case .videoPlayer(let image):
      GalleryVideoPlayerView(image: image)
    }
  }
}

// MARK: - Shared audio player

@MainActor
final class GalleryMediaPlayer: ObservableObject {
  static let shared = GalleryMediaPlayer()

  @Published private(set) var playingEngagementKey: String?
  @Published private(set) var isPlaying = false

  private var player: AVPlayer?
  private var endCancellable: AnyCancellable?

  private init() {}

  func isPlaying(_ image: GalleryImage) -> Bool {
    playingEngagementKey == image.engagementKey && isPlaying
  }

  func toggle(_ image: GalleryImage) {
    guard image.mediaType == .music else { return }
    guard let mediaURL = image.mediaURL else { return }

    if playingEngagementKey == image.engagementKey {
      if isPlaying {
        player?.pause()
        isPlaying = false
      } else {
        player?.play()
        isPlaying = true
      }
      return
    }

    stop()
    configureAudioSession()
    let item = AVPlayerItem(url: mediaURL)
    let newPlayer = AVPlayer(playerItem: item)
    player = newPlayer
    playingEngagementKey = image.engagementKey
    isPlaying = true
    newPlayer.play()

    endCancellable = NotificationCenter.default
      .publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.handlePlaybackEnded()
      }
  }

  func stop() {
    endCancellable = nil
    player?.pause()
    player = nil
    playingEngagementKey = nil
    isPlaying = false
  }

  private func handlePlaybackEnded() {
    player?.seek(to: .zero)
    isPlaying = false
  }

  private func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default)
    try? session.setActive(true)
  }
}

// MARK: - Thumbnail chrome

/// music：封面中央播放/暂停；video：角标提示可进播放页。
struct GalleryMediaTypeChrome: View {
  let image: GalleryImage
  var compact: Bool = false

  @ObservedObject private var mediaPlayer = GalleryMediaPlayer.shared

  var body: some View {
    switch image.mediaType {
    case .photo:
      EmptyView()
    case .music:
      musicControls
    case .video:
      videoBadge
    }
  }

  private var musicControls: some View {
    ZStack {
      Button {
        mediaPlayer.toggle(image)
      } label: {
        Image(systemName: mediaPlayer.isPlaying(image) ? "pause.fill" : "play.fill")
          .font(.system(size: compact ? 14 : 18, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: compact ? 36 : 48, height: compact ? 36 : 48)
          .background(.black.opacity(0.48), in: Circle())
          .overlay {
            Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1)
          }
          .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
      }
      .buttonStyle(.plain)
      .disabled(image.mediaURL == nil)
      .opacity(image.mediaURL == nil ? 0.45 : 1)
      .accessibilityLabel(mediaPlayer.isPlaying(image) ? "暂停" : "播放")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var videoBadge: some View {
    VStack {
      HStack {
        Spacer()
        Image(systemName: "play.rectangle.fill")
          .font(.system(size: compact ? 11 : 13, weight: .semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, compact ? 6 : 8)
          .padding(.vertical, compact ? 4 : 5)
          .background(.black.opacity(0.48), in: Capsule())
          .padding(compact ? 6 : 8)
      }
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

// MARK: - Video page

struct GalleryVideoPlayerView: View {
  let image: GalleryImage

  @Environment(\.dismiss) private var dismiss
  @State private var player: AVPlayer?

  var body: some View {
    NavigationStack {
      ZStack {
        Color.black.ignoresSafeArea()

        if let player {
          VideoPlayer(player: player)
            .ignoresSafeArea(edges: .bottom)
        } else {
          unavailableState
        }
      }
      .navigationTitle(image.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("关闭") {
            player?.pause()
            dismiss()
          }
        }
      }
      .toolbarColorScheme(.dark, for: .navigationBar)
    }
    .onAppear(perform: startPlayback)
    .onDisappear {
      player?.pause()
      player = nil
    }
  }

  private var unavailableState: some View {
    VStack(spacing: 14) {
      GalleryThumbnailImage(url: image.url)
        .frame(width: 160, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

      Image(systemName: "play.slash.fill")
        .font(.title)
        .foregroundStyle(.white.opacity(0.7))

      Text("暂无视频地址")
        .font(.headline)
        .foregroundStyle(.white)

      Text("后续接入真实数据后即可在此播放")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.7))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
    }
  }

  private func startPlayback() {
    guard let mediaURL = image.mediaURL else { return }
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .moviePlayback)
    try? session.setActive(true)
    let newPlayer = AVPlayer(url: mediaURL)
    player = newPlayer
    newPlayer.play()
  }
}
