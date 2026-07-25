//
//  HomeFolderBar.swift
//  b-app-search
//

import SwiftUI

struct HomePrivateFolderToolbar: View {
  @EnvironmentObject private var galleryStore: GalleryStore

  @Binding var selectedFolderId: String

  @AppStorage(AppSettings.iosPhotoLibrarySyncEnabledKey) private var iosPhotoLibrarySyncEnabled = false
  @AppStorage(AppSettings.iosPhotoLibrarySyncActiveKey) private var iosPhotoLibrarySyncActive = false

  @State private var showNewFolderAlert = false
  @State private var newFolderName = ""
  @State private var syncErrorMessage: String?
  @State private var isSyncing = false

  var body: some View {
    HStack(spacing: 8) {
      if iosPhotoLibrarySyncEnabled {
        HStack(spacing: 4) {
          Image(systemName: "photo.on.rectangle.angled")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(iosPhotoLibrarySyncActive ? Color(red: 0.22, green: 0.48, blue: 0.95) : .secondary)
          Toggle(isOn: $iosPhotoLibrarySyncActive) {
            Text("相册同步")
              .font(.caption2)
          }
          .toggleStyle(.switch)
          .controlSize(.mini)
          .labelsHidden()
          .onChange(of: iosPhotoLibrarySyncActive) { active in
            AppSettings.setIOSPhotoLibrarySyncActive(active)
            if active {
              performPhotoLibrarySync()
            }
          }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemFill), in: Capsule())
        .accessibilityLabel("iOS 相册同步")
        .accessibilityValue(iosPhotoLibrarySyncActive ? "已开启" : "已关闭")
      }

      if isSyncing {
        ProgressView()
          .controlSize(.small)
      }

      Button {
        newFolderName = ""
        showNewFolderAlert = true
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "folder.badge.plus")
          Text("")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color(red: 0.42, green: 0.38, blue: 0.55))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemBackground).opacity(0.72), in: Capsule())
      }
      .buttonStyle(.plain)
    }
    .alert("新建文件夹", isPresented: $showNewFolderAlert) {
      TextField("文件夹名称", text: $newFolderName)
      Button("创建") {
        if let folder = galleryStore.addFolder(name: newFolderName) {
          selectedFolderId = folder.id
        }
      }
      Button("取消", role: .cancel) {}
    }
    .alert("相册同步失败", isPresented: syncErrorBinding) {
      Button("确定", role: .cancel) { syncErrorMessage = nil }
    } message: {
      Text(syncErrorMessage ?? "")
    }
  }

  private var syncErrorBinding: Binding<Bool> {
    Binding(
      get: { syncErrorMessage != nil },
      set: { if !$0 { syncErrorMessage = nil } }
    )
  }

  private func performPhotoLibrarySync() {
    isSyncing = true
    Task {
      do {
        try await IOSPhotoLibrarySyncService.shared.requestAuthorizationIfNeeded()
        try await IOSPhotoLibrarySyncService.shared.syncAll(from: galleryStore)
      } catch {
        syncErrorMessage = error.localizedDescription
        iosPhotoLibrarySyncActive = false
        AppSettings.setIOSPhotoLibrarySyncActive(false)
      }
      isSyncing = false
    }
  }
}

struct HomeFolderBar: View {
  @EnvironmentObject private var galleryStore: GalleryStore

  let currentImageFolderId: String?
  @Binding var selectedFolderId: String
  var imageCount: ((String) -> Int)?
  var onImageDropped: (String, String) -> Void

  @AppStorage(AppSettings.iosPhotoLibrarySyncEnabledKey) private var iosPhotoLibrarySyncEnabled = false
  @AppStorage(AppSettings.iosPhotoLibrarySyncActiveKey) private var iosPhotoLibrarySyncActive = false

  @State private var dropTargetFolderId: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(galleryStore.displayPrivateFolders) { folder in
              HomeFolderChip(
                folder: folder,
                count: resolvedImageCount(for: folder.id),
                isSelected: selectedFolderId == folder.id,
                isCurrentImageFolder: currentImageFolderId == folder.id,
                isDropTarget: dropTargetFolderId == folder.id
              ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                  selectedFolderId = folder.id
                }
              }
              .dropDestination(for: String.self) { items, _ in
                guard folder.id != GalleryFolder.allId else { return false }
                guard let engagementKey = items.first else { return false }
                onImageDropped(engagementKey, folder.id)
                return true
              } isTargeted: { isTargeted in
                if isTargeted {
                  dropTargetFolderId = folder.id
                } else if dropTargetFolderId == folder.id {
                  dropTargetFolderId = nil
                }
              }
              .id(folder.id)
            }
          }
          .padding(.horizontal, 2)
          .padding(.vertical, 2)
        }
        .onChange(of: currentImageFolderId) { folderId in
          guard let folderId else { return }
          withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(folderId, anchor: .center)
          }
        }
        .onAppear {
          if let folderId = currentImageFolderId {
            proxy.scrollTo(folderId, anchor: .center)
          }
        }
      }

      Text(hintText)
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 4)
    }
  }

  private var hintText: String {
    if iosPhotoLibrarySyncEnabled, iosPhotoLibrarySyncActive {
      return "拖动图片可在私人文件夹间整理；发布请到图片管理"
    }
    if iosPhotoLibrarySyncEnabled {
      return "仅自己可见；打开相册同步后可写入系统相簿"
    }
    return "仅自己可见；拖动图片可在文件夹间整理"
  }

  private func resolvedImageCount(for folderId: String) -> Int {
    if let imageCount {
      return imageCount(folderId)
    }
    return galleryStore.privateImageCount(inFolder: folderId)
  }
}

private struct HomeFolderChip: View {
  let folder: GalleryFolder
  let count: Int
  let isSelected: Bool
  let isCurrentImageFolder: Bool
  let isDropTarget: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 4) {
        Image(systemName: folder.iconName)
          .font(.caption2.weight(.semibold))
        Text(folder.name)
          .font(.caption.weight(.semibold))
          .lineLimit(1)
        Text("\(count)")
          .font(.system(size: 10, weight: .bold))
          .padding(.horizontal, 5)
          .padding(.vertical, 1)
          .background(chipBadgeBackground, in: Capsule())
      }
      .foregroundStyle(foregroundColor)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(chipBackground, in: Capsule())
      .overlay {
        Capsule()
          .strokeBorder(borderColor, lineWidth: isCurrentImageFolder || isDropTarget ? 1.5 : 0)
      }
      .scaleEffect(isDropTarget ? 1.03 : 1)
      .animation(.easeInOut(duration: 0.15), value: isDropTarget)
    }
    .buttonStyle(.plain)
  }

  private var foregroundColor: Color {
    if isSelected { return .white }
    if isCurrentImageFolder { return Color(red: 0.22, green: 0.48, blue: 0.95) }
    return .primary
  }

  private var chipBackground: some ShapeStyle {
    if isDropTarget {
      return AnyShapeStyle(Color(red: 0.22, green: 0.48, blue: 0.95).opacity(0.2))
    }
    if isSelected {
      return AnyShapeStyle(Color(red: 0.22, green: 0.48, blue: 0.95))
    }
    return AnyShapeStyle(Color(.tertiarySystemFill))
  }

  private var chipBadgeBackground: Color {
    isSelected ? .white.opacity(0.22) : Color(.systemBackground).opacity(0.65)
  }

  private var borderColor: Color {
    if isDropTarget { return Color(red: 0.22, green: 0.48, blue: 0.95) }
    if isCurrentImageFolder { return Color(red: 0.22, green: 0.48, blue: 0.95).opacity(0.85) }
    return .clear
  }
}
