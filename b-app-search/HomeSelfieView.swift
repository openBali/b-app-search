//
//  HomeSelfieView.swift
//  b-app-search
//

import SwiftUI

struct HomeSelfieView: View {
  let onOpenMapForImage: (GalleryImage) -> Void

  @Environment(\.appSkin) private var appSkin
  @ObservedObject private var galleryStore = GalleryStore.shared
  @EnvironmentObject private var tagStore: ImageTagStore

  @State private var isSearchActive = false
  @State private var searchText = ""
  @FocusState private var isSearchFocused: Bool
  @State private var privateSelectedIndex = 0
  @State private var selectedPrivateFolderId = GalleryFolder.allId
  @State private var selectedMediaDestination: GalleryMediaOpenDestination?
  @State private var showManageGallery = false
  @State private var displayMode: HomeNetworkDisplayMode = .waterfall
  @State private var selectedTags: Set<String> = []
  @State private var showTagFilterSheet = false

  private let horizontalPadding: CGFloat = 20
  private var selfieTint: Color { appSkin.tokens.selfieTint }

  private var selfieFolderImages: [GalleryImage] {
    galleryStore.selfieImages(inFolder: selectedPrivateFolderId)
  }

  private var selfieDisplayImages: [GalleryImage] {
    guard !selectedTags.isEmpty else { return selfieFolderImages }
    return selfieFolderImages.filter { selectedTags.contains($0.tag) }
  }

  private var unpublishedImageCount: Int {
    galleryStore.privateImages.count
  }

  private var publishedImageCount: Int {
    galleryStore.userImages.filter(\.isPublished).count
  }

  private var currentPrivateImage: GalleryImage? {
    guard selfieDisplayImages.indices.contains(privateSelectedIndex) else { return nil }
    return selfieDisplayImages[privateSelectedIndex]
  }

  private var currentPrivateFolderId: String? {
    guard let currentPrivateImage else { return nil }
    return galleryStore.privateFolderId(for: currentPrivateImage)
  }

  private var filterTags: [String] {
    tagStore.mergedTags(extraFromImages: selfieFolderImages.map(\.tag))
  }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: appSkin.tokens.heroGradient,
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .opacity(0.22)
      .ignoresSafeArea()
      .background(appSkin.tokens.canvasBackground.ignoresSafeArea())

      VStack(spacing: 0) {
        homeSearchHeader

        if isSearchActive {
          HomeInlineSearchContent(
            searchText: $searchText,
            isSearchFocused: $isSearchFocused,
            horizontalInset: horizontalPadding,
            onLocationTap: { image in
              dismissSearch()
              onOpenMapForImage(image)
            }
          )
          .transition(.opacity)
        } else {
          ScrollView {
            VStack(alignment: .leading, spacing: 12) {
              HStack(spacing: 8) {
                Spacer(minLength: 0)
                displayModeToggle
                tagFilterEntry
                manageGalleryEntry
              }

              HomePanelSection(
                title: "Selfie",
                tint: selfieTint
              ) {
                privateSection
              } middle: {
                Text("")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
              } trailing: {
                HomePrivateFolderToolbar(selectedFolderId: $selectedPrivateFolderId)
              }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 28)
          }
          .transition(.opacity)
        }
      }
      .animation(.easeInOut(duration: 0.2), value: isSearchActive)
    }
    .navigationTitle("Selfie")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      reconcileFolderSelection()
      syncPrivateIndex()
    }
    .onChange(of: galleryStore.userImages.map(\.id)) { _ in
      reconcileFolderSelection()
      syncPrivateIndex()
    }
    .onChange(of: selfieDisplayImages.map(\.engagementKey)) { _ in
      syncPrivateIndex()
    }
    .onChange(of: selectedPrivateFolderId) { _ in
      privateSelectedIndex = 0
      syncPrivateIndex()
    }
    .onChange(of: selectedTags) { _ in
      privateSelectedIndex = 0
      syncPrivateIndex()
    }
    .onChange(of: showManageGallery) { isShowing in
      guard !isShowing else { return }
      reconcileFolderSelection()
      syncPrivateIndex()
    }
    .fullScreenCover(item: $selectedMediaDestination) { destination in
      GalleryMediaDestinationView(
        destination: destination,
        onLocationTap: { image in
          selectedMediaDestination = nil
          onOpenMapForImage(image)
        },
        onCurrentImageChanged: { current in
          if let index = selfieDisplayImages.firstIndex(where: { $0.id == current.id }) {
            privateSelectedIndex = index
          }
        }
      )
    }
    .navigationDestination(isPresented: $showManageGallery) {
      GalleryManageView()
        .environmentObject(galleryStore)
        .environmentObject(tagStore)
    }
    .sheet(isPresented: $showTagFilterSheet) {
      tagFilterSheet
    }
  }

  private var homeSearchHeader: some View {
    HStack(spacing: 10) {
      if isSearchActive {
        Button(action: dismissSearch) {
          Image(systemName: "chevron.left")
            .font(.body.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: 36, height: 36)
            .background(Color(.secondarySystemGroupedBackground), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("返回")
        .transition(.move(edge: .leading).combined(with: .opacity))
      }

      Group {
        if isSearchActive {
          HomeSearchInputBar(searchText: $searchText, isFocused: $isSearchFocused)
        } else {
          HomeSearchBar(onActivate: activateSearch)
        }
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.horizontal, horizontalPadding)
    .padding(.top, 8)
    .padding(.bottom, isSearchActive ? 12 : 16)
  }

  private var privateSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      statusCaption

      HomeFolderBar(
        currentImageFolderId: currentPrivateFolderId,
        selectedFolderId: $selectedPrivateFolderId,
        imageCount: { galleryStore.selfieImageCount(inFolder: $0) },
        onImageDropped: handleImageDropped
      )
      .id(galleryStore.userImages.map(\.id))

      selfieFeed
        .animation(.easeInOut(duration: 0.2), value: displayMode)
        .animation(.easeInOut(duration: 0.2), value: selectedTags)
    }
  }

  @ViewBuilder
  private var statusCaption: some View {
    if galleryStore.userImages.isEmpty {
      Text("上传的图片会保存在这里；发布后会同步出现在首页 Network。")
        .font(.caption2)
        .foregroundStyle(.secondary)
    } else if unpublishedImageCount == 0, publishedImageCount > 0, selectedPrivateFolderId != GalleryFolder.allId {
      Text("这 \(publishedImageCount) 张图片已全部发布，可切换到「全部」或在首页查看。")
        .font(.caption2)
        .foregroundStyle(.secondary)
    } else if selfieDisplayImages.isEmpty {
      Text(selectedTags.isEmpty
           ? "当前文件夹暂无图片，可点上方「全部」查看所有上传。"
           : "该标签下暂无图片")
        .font(.caption2)
        .foregroundStyle(.secondary)
    } else {
      Text("共 \(selfieDisplayImages.count) 张\(selectedPrivateFolderId == GalleryFolder.allId ? "" : "未发布")图片")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var selfieFeed: some View {
    switch displayMode {
    case .network:
      HomeHorizontalMasonryView(
        images: selfieDisplayImages,
        selectedIndex: $privateSelectedIndex,
        canMoveImage: { galleryStore.canMoveInPrivateSection($0) },
        showsPublishedBadge: true,
        onImageDoubleTap: { image, _ in
          selectedMediaDestination = .open(image, in: selfieDisplayImages)
        },
        emptyMessage: selfieEmptyMessage
      )
      .id(galleryStore.userImages.map(\.id))

    case .waterfall:
      if galleryStore.userImages.isEmpty {
        addImagesPrompt
      }

      if selfieDisplayImages.isEmpty {
        filteredEmptyState
      } else {
        GalleryWaterfallView(
          images: selfieDisplayImages,
          horizontalInset: 0,
          groupSimilarImages: false,
          onImageTap: { image in
            selectedMediaDestination = .open(image, in: selfieDisplayImages)
            if let index = selfieDisplayImages.firstIndex(where: { $0.id == image.id }) {
              privateSelectedIndex = index
            }
          },
          onLocationTap: onOpenMapForImage
        )
        .id(galleryStore.userImages.map(\.id))
      }
    }
  }

  private var displayModeToggle: some View {
    HStack(spacing: 2) {
      displayModeButton(mode: .network, icon: "rectangle.grid.1x2.fill", label: "横条")
      displayModeButton(mode: .waterfall, icon: "square.grid.2x2.fill", label: "瀑布")
    }
    .padding(3)
    .background(Color(.systemBackground).opacity(0.72), in: Capsule())
  }

  private func displayModeButton(mode: HomeNetworkDisplayMode, icon: String, label: String) -> some View {
    let isSelected = displayMode == mode

    return Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        displayMode = mode
      }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: icon)
        Text(label)
      }
      .font(.caption2.weight(.semibold))
      .foregroundStyle(isSelected ? selfieTint : .secondary)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(isSelected ? selfieTint.opacity(0.14) : Color.clear, in: Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(label)模式")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var tagFilterEntry: some View {
    Button {
      showTagFilterSheet = true
    } label: {
      HStack(spacing: 4) {
        Image(systemName: "line.3.horizontal.decrease.circle")
        Text("筛选")
        if !selectedTags.isEmpty {
          Text("\(selectedTags.count)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(selfieTint, in: Capsule())
        }
      }
      .font(.caption2.weight(.semibold))
      .foregroundStyle(!selectedTags.isEmpty ? selfieTint : .secondary)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(
        !selectedTags.isEmpty ? selfieTint.opacity(0.14) : Color(.systemBackground).opacity(0.72),
        in: Capsule()
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("标签筛选")
  }

  private var manageGalleryEntry: some View {
    Button {
      showManageGallery = true
    } label: {
      HStack(spacing: 4) {
        Image(systemName: "plus.circle.fill")
        Text("添加")
        Image(systemName: "chevron.right")
          .font(.caption2.weight(.bold))
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(selfieTint)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Color(.systemBackground).opacity(0.72), in: Capsule())
    }
    .buttonStyle(.plain)
  }

  private var addImagesPrompt: some View {
    Button {
      showManageGallery = true
    } label: {
      HStack(spacing: 12) {
        Image(systemName: "plus.circle.fill")
          .font(.title3)
          .foregroundStyle(selfieTint)
        VStack(alignment: .leading, spacing: 4) {
          Text("添加你的图片")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
          Text("上传后可在发布中批量公开到 Network")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(12)
      .background(Color(.systemBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private var filteredEmptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "photo.on.rectangle.angled")
        .font(.title2)
        .foregroundStyle(.secondary)
      Text(selfieEmptyMessage)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
  }

  private var tagFilterSheet: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 12) {
        if !selectedTags.isEmpty {
          Text("已选 \(selectedTags.count) 个标签")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text("共 \(filterTags.count) 个标签")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        HomeTagFilterBar(
          tags: filterTags,
          selectedTags: $selectedTags,
          tint: selfieTint,
          layout: .expanded
        )
      }
      .padding(.horizontal, 20)
      .padding(.top, 8)
      .padding(.bottom, 16)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(Color(.systemGroupedBackground))
      .navigationTitle("标签筛选")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("完成") {
            showTagFilterSheet = false
          }
        }
        if !selectedTags.isEmpty {
          ToolbarItem(placement: .primaryAction) {
            Button("清除") {
              withAnimation(.easeInOut(duration: 0.2)) {
                selectedTags.removeAll()
              }
            }
          }
        }
      }
      .task {
        if tagStore.remoteTags.isEmpty, !tagStore.isLoadingRemote {
          await tagStore.fetchRemoteTags()
        }
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }

  private func activateSearch() {
    withAnimation(.easeInOut(duration: 0.2)) {
      isSearchActive = true
    }
    DispatchQueue.main.async {
      isSearchFocused = true
    }
  }

  private func dismissSearch() {
    isSearchFocused = false
    withAnimation(.easeInOut(duration: 0.2)) {
      isSearchActive = false
      searchText = ""
    }
  }

  private var selfieEmptyMessage: String {
    if galleryStore.userImages.isEmpty {
      return "暂无图片，可点击上方添加"
    }
    if !selectedTags.isEmpty {
      return "该标签下暂无图片"
    }
    if unpublishedImageCount == 0, publishedImageCount > 0 {
      return "图片已全部发布，请切换到「全部」或在首页查看"
    }
    return "当前文件夹暂无图片，请切换到「全部」"
  }

  private func reconcileFolderSelection() {
    guard selfieFolderImages.isEmpty else { return }
    guard galleryStore.userImages.count > 0 else { return }
    guard selectedPrivateFolderId != GalleryFolder.allId else { return }
    selectedPrivateFolderId = GalleryFolder.allId
  }

  private func syncPrivateIndex() {
    guard !selfieDisplayImages.isEmpty else {
      privateSelectedIndex = 0
      return
    }
    if privateSelectedIndex >= selfieDisplayImages.count {
      privateSelectedIndex = selfieDisplayImages.count - 1
    }
  }

  private func handleImageDropped(engagementKey: String, folderId: String) {
    galleryStore.moveImage(engagementKey: engagementKey, toFolderId: folderId)
    syncPrivateIndex()
  }
}
