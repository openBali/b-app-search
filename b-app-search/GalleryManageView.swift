//
//  GalleryManageView.swift
//  b-app-search
//

import CoreLocation
import PhotosUI
import SwiftUI

private enum ManageBatchMode {
  case none
  case publish
  case unpublish
  case cloudSync
}

struct GalleryManageView: View {
  @EnvironmentObject private var galleryStore: GalleryStore
  @EnvironmentObject private var tagStore: ImageTagStore

  @State private var editorMode: GalleryImageEditorMode?
  @State private var imagePendingDelete: GalleryImage?
  @State private var batchMode: ManageBatchMode = .none
  @State private var selectedIDs: Set<Int> = []
  @State private var showPublishSuccess = false
  @State private var showUnpublishSuccess = false
  @State private var showCloudSyncSuccess = false
  @State private var batchActionCount = 0
  @State private var syncErrorMessage: String?

  private var unpublishedImages: [GalleryImage] {
    galleryStore.userImages.filter { !$0.isPublished }
  }

  private var publishedImages: [GalleryImage] {
    galleryStore.userImages.filter(\.isPublished)
  }

  private var unsyncedImages: [GalleryImage] {
    galleryStore.userImages.filter { !$0.isCloudSynced }
  }

  private var isBatchMode: Bool {
    batchMode != .none
  }

  var body: some View {
    contentWithChrome
      .manageAlerts(
        deleteBinding: deleteAlertBinding,
        pendingDelete: imagePendingDelete,
        onDelete: { image in galleryStore.deleteImage(image); imagePendingDelete = nil },
        onCancelDelete: { imagePendingDelete = nil },
        showPublishSuccess: $showPublishSuccess,
        publishCount: batchActionCount,
        showUnpublishSuccess: $showUnpublishSuccess,
        unpublishCount: batchActionCount,
        showCloudSyncSuccess: $showCloudSyncSuccess,
        syncCount: batchActionCount,
        syncErrorBinding: syncErrorBinding,
        syncErrorMessage: syncErrorMessage,
        onClearSyncError: { syncErrorMessage = nil }
      )
  }

  private var contentWithChrome: some View {
    mainList
      .id(galleryStore.userImages.map(\.id))
      .navigationTitle("图片管理")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { manageToolbar }
      .overlay { syncOverlay }
      .sheet(item: $editorMode) { mode in
        NavigationStack {
          GalleryImageEditorView(mode: mode)
        }
        .environmentObject(galleryStore)
        .environmentObject(tagStore)
      }
  }

  private var mainList: some View {
    List {
      if galleryStore.userImages.isEmpty {
        emptyStateSection
      } else {
        batchHintSections
        unpublishedSection
        publishedSection
      }
    }
  }

  private var emptyStateSection: some View {
    Section {
      VStack(spacing: 16) {
        Image(systemName: "photo.on.rectangle.angled")
          .font(.system(size: 44))
          .foregroundStyle(.secondary)
        Text("还没有上传图片")
          .font(.headline)
        Text("点击右上角「添加」上传图片，再通过「发布」或「同步」管理图片。")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Button("添加图片") {
          editorMode = .add
        }
        .buttonStyle(.borderedProminent)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 24)
      .listRowBackground(Color.clear)
    }
  }

  @ViewBuilder
  private var batchHintSections: some View {
    if batchMode == .publish {
      Section {
        Text("勾选图片后点右上角「完成」发布到共享图片页")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    if batchMode == .unpublish {
      Section {
        Text("勾选图片后点右上角「完成」下架；下架后可重新发布")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    if batchMode == .cloudSync {
      Section {
        Text("勾选图片后点右上角「完成」同步到云端（不会改为已发布）")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private var unpublishedSection: some View {
    if !unpublishedImages.isEmpty {
      Section {
        ForEach(unpublishedImages) { image in
          ManageImageRowView(
            image: image,
            batchMode: batchMode,
            selectedIDs: selectedIDs,
            selectableWhen: .unpublished,
            onToggle: { toggleSelection(for: $0) },
            onEdit: { editorMode = .edit($0) }
          )
        }
        .onDelete { offsets in
          deleteImages(unpublishedImages, at: offsets)
        }
      } header: {
        Text(unpublishedSectionTitle(unpublishedImages.count))
      }
    }
  }

  @ViewBuilder
  private var publishedSection: some View {
    if !publishedImages.isEmpty {
      Section {
        ForEach(publishedImages) { image in
          ManageImageRowView(
            image: image,
            batchMode: batchMode,
            selectedIDs: selectedIDs,
            selectableWhen: .published,
            onToggle: { toggleSelection(for: $0) },
            onEdit: { editorMode = .edit($0) },
            onUnpublish: { galleryStore.unpublishImages(ids: [$0.id]) },
            onDeleteRequest: { imagePendingDelete = $0 }
          )
        }
      } header: {
        Text(publishedSectionTitle(publishedImages.count))
      } footer: {
        if batchMode == .none {
          Text("左滑可「取消发布」或「删除」；取消发布后图片回到未发布列表，可重新选择发布。")
        }
      }
    }
  }

  @ToolbarContentBuilder
  private var manageToolbar: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      if isBatchMode {
        Button("完成") { confirmBatchMode() }
          .disabled(selectedIDs.isEmpty || (batchMode == .cloudSync && galleryStore.isCloudSyncing))
      } else {
        Button { editorMode = .add } label: {
          Label("添加", systemImage: "plus")
        }
      }
    }
    ToolbarItem(placement: .navigationBarLeading) {
      if !galleryStore.userImages.isEmpty {
        leadingToolbarContent
      }
    }
  }

  @ViewBuilder
  private var syncOverlay: some View {
    if galleryStore.isCloudSyncing {
      ZStack {
        Color.black.opacity(0.15).ignoresSafeArea()
        ProgressView("同步到云端…")
          .padding(24)
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
    }
  }

  @ViewBuilder
  private var leadingToolbarContent: some View {
    switch batchMode {
    case .publish, .unpublish, .cloudSync:
      Button("取消") { exitBatchMode() }
        .disabled(batchMode == .cloudSync && galleryStore.isCloudSyncing)
    case .none:
      HStack(spacing: 12) {
        Button("发布") {
          enterBatchMode(.publish, preselected: unpublishedImages.map(\.id))
        }
        .disabled(unpublishedImages.isEmpty)

        Button("取消发布") {
          enterBatchMode(.unpublish, preselected: publishedImages.map(\.id))
        }
        .disabled(publishedImages.isEmpty)

        Button("同步") {
          enterBatchMode(.cloudSync, preselected: unsyncedImages.map(\.id))
        }
        .disabled(unsyncedImages.isEmpty)
      }
    }
  }

  private func publishedSectionTitle(_ count: Int) -> String {
    if batchMode == .unpublish {
      return "已发布（可选 \(selectedIDs.count)/\(count)）"
    }
    return "已发布（\(count)）"
  }

  private func unpublishedSectionTitle(_ count: Int) -> String {
    if batchMode == .publish {
      return "未发布（可选 \(selectedIDs.count)/\(count)）"
    }
    if batchMode == .cloudSync {
      let unsyncedCount = galleryStore.userImages.filter { !$0.isCloudSynced }.count
      return "未发布（\(count)）· 可同步 \(unsyncedCount) 张"
    }
    return "未发布（\(count)）"
  }

  private var deleteAlertBinding: Binding<Bool> {
    Binding(
      get: { imagePendingDelete != nil },
      set: { if !$0 { imagePendingDelete = nil } }
    )
  }

  private var syncErrorBinding: Binding<Bool> {
    Binding(
      get: { syncErrorMessage != nil },
      set: { if !$0 { syncErrorMessage = nil } }
    )
  }

  private func enterBatchMode(_ mode: ManageBatchMode, preselected: [Int]) {
    batchMode = mode
    selectedIDs = Set(preselected)
  }

  private func exitBatchMode() {
    batchMode = .none
    selectedIDs.removeAll()
  }

  private func confirmBatchMode() {
    guard !selectedIDs.isEmpty else {
      exitBatchMode()
      return
    }
    switch batchMode {
    case .publish:
      publishSelectedImages()
    case .unpublish:
      unpublishSelectedImages()
    case .cloudSync:
      syncSelectedImages()
    case .none:
      break
    }
  }

  private func toggleSelection(for id: Int) {
    if selectedIDs.contains(id) {
      selectedIDs.remove(id)
    } else {
      selectedIDs.insert(id)
    }
  }

  private func publishSelectedImages() {
    batchActionCount = selectedIDs.count
    galleryStore.publishImages(ids: selectedIDs)
    exitBatchMode()
    showPublishSuccess = true
  }

  private func unpublishSelectedImages() {
    batchActionCount = selectedIDs.count
    galleryStore.unpublishImages(ids: selectedIDs)
    exitBatchMode()
    showUnpublishSuccess = true
  }

  private func syncSelectedImages() {
    let ids = selectedIDs
    Task {
      do {
        try await galleryStore.syncImagesToCloud(ids: ids)
        batchActionCount = ids.count
        exitBatchMode()
        showCloudSyncSuccess = true
      } catch {
        syncErrorMessage = error.localizedDescription
      }
    }
  }

  private func deleteImages(_ source: [GalleryImage], at offsets: IndexSet) {
    for index in offsets {
      galleryStore.deleteImage(source[index])
    }
  }
}

private enum ManageSelectableWhen {
  case unpublished
  case published
}

private struct ManageImageRowView: View {
  let image: GalleryImage
  let batchMode: ManageBatchMode
  let selectedIDs: Set<Int>
  let selectableWhen: ManageSelectableWhen
  let onToggle: (Int) -> Void
  let onEdit: (GalleryImage) -> Void
  var onUnpublish: ((GalleryImage) -> Void)?
  var onDeleteRequest: ((GalleryImage) -> Void)?

  private var isBatchMode: Bool { batchMode != .none }

  private var canSelect: Bool {
    switch batchMode {
    case .publish:
      return selectableWhen == .unpublished && !image.isPublished
    case .unpublish:
      return selectableWhen == .published && image.isPublished
    case .cloudSync:
      return !image.isCloudSynced
    case .none:
      return false
    }
  }

  private var showsPublishedSwipe: Bool {
    batchMode == .none && selectableWhen == .published && image.isPublished
  }

  var body: some View {
    Group {
      if showsPublishedSwipe, let onUnpublish, let onDeleteRequest {
        rowBody
          .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button("取消发布") { onUnpublish(image) }
              .tint(.orange)
          }
          .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("删除", role: .destructive) { onDeleteRequest(image) }
          }
      } else {
        rowBody
      }
    }
  }

  @ViewBuilder
  private var rowBody: some View {
    if canSelect {
      Button { onToggle(image.id) } label: {
        GalleryManageRow(
          image: image,
          isSelected: selectedIDs.contains(image.id),
          showsSelection: true
        )
      }
      .buttonStyle(.plain)
    } else if isBatchMode {
      GalleryManageRow(image: image, showsSelection: true, isSelectionDisabled: true)
    } else {
      Button { onEdit(image) } label: {
        GalleryManageRow(image: image)
      }
      .buttonStyle(.plain)
    }
  }
}

private extension View {
  func manageAlerts(
    deleteBinding: Binding<Bool>,
    pendingDelete: GalleryImage?,
    onDelete: @escaping (GalleryImage) -> Void,
    onCancelDelete: @escaping () -> Void,
    showPublishSuccess: Binding<Bool>,
    publishCount: Int,
    showUnpublishSuccess: Binding<Bool>,
    unpublishCount: Int,
    showCloudSyncSuccess: Binding<Bool>,
    syncCount: Int,
    syncErrorBinding: Binding<Bool>,
    syncErrorMessage: String?,
    onClearSyncError: @escaping () -> Void
  ) -> some View {
    self
      .alert("删除图片", isPresented: deleteBinding) {
        Button("删除", role: .destructive) {
          if let pendingDelete { onDelete(pendingDelete) }
        }
        Button("取消", role: .cancel, action: onCancelDelete)
      } message: {
        if let pendingDelete {
          Text("确定删除「\(pendingDelete.title)」？此操作不可恢复。")
        }
      }
      .alert("发布成功", isPresented: showPublishSuccess) {
        Button("确定", role: .cancel) {}
      } message: {
        Text("已将 \(publishCount) 张图片发布到共享图片页。")
      }
      .alert("已取消发布", isPresented: showUnpublishSuccess) {
        Button("确定", role: .cancel) {}
      } message: {
        Text("已将 \(unpublishCount) 张图片从共享页下架，可在「发布」中重新选择。")
      }
      .alert("同步成功", isPresented: showCloudSyncSuccess) {
        Button("确定", role: .cancel) {}
      } message: {
        Text("已将 \(syncCount) 张图片同步到云端（mock）。")
      }
      .alert("同步失败", isPresented: syncErrorBinding) {
        Button("确定", role: .cancel, action: onClearSyncError)
      } message: {
        Text(syncErrorMessage ?? "")
      }
  }
}

private struct GalleryManageRow: View {
  let image: GalleryImage
  var isSelected: Bool = false
  var showsSelection: Bool = false
  var isSelectionDisabled: Bool = false

  var body: some View {
    HStack(spacing: 12) {
      if showsSelection {
        Image(systemName: isSelectionDisabled ? "checkmark.circle.fill" : (isSelected ? "checkmark.circle.fill" : "circle"))
          .font(.title3)
          .foregroundStyle(
            isSelectionDisabled
              ? Color(.tertiaryLabel)
              : (isSelected ? Color(red: 0.28, green: 0.48, blue: 0.98) : .secondary)
          )
      }

      GalleryThumbnailImage(url: image.url)
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(image.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
          if image.isPublished {
            statusBadge("已发布", color: Color(red: 0.22, green: 0.72, blue: 0.52))
          }
          if image.isCloudSynced {
            statusBadge("已同步", color: Color(red: 0.28, green: 0.48, blue: 0.98))
          }
        }
        HStack(spacing: 6) {
          Text(image.tag)
            .font(.caption)
            .foregroundStyle(image.category.pinColor)
          if image.hasLocation {
            Label(image.locationLabel, systemImage: "mappin")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        Text(image.description)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      Spacer(minLength: 0)

      if !showsSelection {
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
    }
    .padding(.vertical, 4)
  }

  private func statusBadge(_ title: String, color: Color) -> some View {
    Text(title)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(color, in: Capsule())
  }
}

enum GalleryImageEditorMode: Identifiable {
  case add
  case edit(GalleryImage)

  var id: String {
    switch self {
    case .add: return "add"
    case .edit(let image): return "edit-\(image.id)"
    }
  }
}

struct GalleryImageEditorView: View {
  @EnvironmentObject private var galleryStore: GalleryStore
  @EnvironmentObject private var tagStore: ImageTagStore
  @Environment(\.dismiss) private var dismiss

  let mode: GalleryImageEditorMode

  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var previewImage: UIImage?
  @State private var pendingImageData: Data?
  @State private var title = ""
  @State private var tag = "自然"
  @State private var description = ""
  @State private var locationName = ""
  @State private var latitudeText = ""
  @State private var longitudeText = ""
  @State private var hasEmbeddedLocation = false
  @State private var errorMessage: String?
  @State private var isSaving = false

  private var tagOptions: [String] {
    var options = tagStore.mergedTags()
    if !options.contains(tag) {
      options.append(tag)
    }
    return options
  }

  private var isEditing: Bool {
    if case .edit = mode { return true }
    return false
  }

  private var navigationTitle: String {
    isEditing ? "编辑图片" : "添加图片"
  }

  var body: some View {
    Form {
      Section("图片") {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
          HStack(spacing: 12) {
            Group {
              if let previewImage {
                Image(uiImage: previewImage)
                  .resizable()
                  .scaledToFill()
              } else {
                Color(.tertiarySystemFill)
                  .overlay {
                    Image(systemName: "photo.badge.plus")
                      .font(.title2)
                      .foregroundStyle(.secondary)
                  }
              }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
              Text(isEditing ? "更换图片（可选）" : "选择图片")
                .font(.subheadline.weight(.semibold))
              Text("支持从相册选取")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
        .onChange(of: selectedPhotoItem) { newItem in
          guard let newItem else { return }
          Task {
            if let data = try? await newItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data)
            {
              await MainActor.run {
                previewImage = image
                pendingImageData = data
                applyLocationFromImageData(data)
              }
            }
          }
        }
      }

      Section("基本信息") {
        TextField("标题", text: $title)
        Picker("标签", selection: $tag) {
          ForEach(tagOptions, id: \.self) { option in
            Text(option).tag(option)
          }
        }
        TextField("描述", text: $description, axis: .vertical)
          .lineLimit(3...6)
      }

      locationSection
    }
    .navigationTitle(navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("取消") { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button(isEditing ? "保存" : "上传") {
          save()
        }
        .disabled(!canSave || isSaving)
      }
    }
    .alert("无法保存", isPresented: errorBinding) {
      Button("确定", role: .cancel) { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "")
    }
    .onAppear(perform: loadExistingIfNeeded)
  }

  @ViewBuilder
  private var locationSection: some View {
    Section {
      TextField("地点名称", text: $locationName)

      if hasEmbeddedLocation {
        LabeledContent("纬度") {
          Text(latitudeText)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        LabeledContent("经度") {
          Text(longitudeText)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        Text("图片自带 GPS 坐标，经纬度不可修改；地图仍按坐标定位。")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        if hasManualCoordinates {
          LabeledContent("纬度") {
            Text(latitudeText)
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
          LabeledContent("经度") {
            Text(longitudeText)
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
        } else {
          Text("尚未设置位置，可在地图上选取或手动输入经纬度。")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        NavigationLink {
          MapLocationPickerView(initialCoordinate: currentCoordinate) { coordinate in
            applyManualCoordinate(coordinate)
          }
        } label: {
          Label("在地图上选取位置", systemImage: "map")
        }

        TextField("纬度", text: $latitudeText)
          .keyboardType(.decimalPad)
        TextField("经度", text: $longitudeText)
          .keyboardType(.decimalPad)

        if hasManualCoordinates {
          Button("清除位置", role: .destructive) {
            latitudeText = ""
            longitudeText = ""
          }
        }
      }
    } header: {
      Text("地理位置（可选）")
    }
  }

  private var hasManualCoordinates: Bool {
    Double(latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
      && Double(longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
  }

  private var currentCoordinate: CLLocationCoordinate2D? {
    guard
      let latitude = Double(latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)),
      let longitude = Double(longitudeText.trimmingCharacters(in: .whitespacesAndNewlines))
    else { return nil }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  private func applyManualCoordinate(_ coordinate: CLLocationCoordinate2D) {
    hasEmbeddedLocation = false
    latitudeText = String(format: "%.6f", coordinate.latitude)
    longitudeText = String(format: "%.6f", coordinate.longitude)
  }

  private func applyLocationFromImageData(_ data: Data) {
    if let coordinate = ImageEXIFLocationExtractor.coordinate(from: data) {
      hasEmbeddedLocation = true
      latitudeText = String(format: "%.6f", coordinate.latitude)
      longitudeText = String(format: "%.6f", coordinate.longitude)
    } else {
      hasEmbeddedLocation = false
      if !isEditing {
        latitudeText = ""
        longitudeText = ""
      }
    }
  }

  private func loadLocationFromFileData(_ data: Data, fallbackImage: GalleryImage) {
    if let coordinate = ImageEXIFLocationExtractor.coordinate(from: data) {
      hasEmbeddedLocation = true
      latitudeText = String(format: "%.6f", coordinate.latitude)
      longitudeText = String(format: "%.6f", coordinate.longitude)
    } else {
      hasEmbeddedLocation = fallbackImage.hasEmbeddedLocation
      if fallbackImage.hasLocation {
        latitudeText = String(format: "%.6f", fallbackImage.latitude)
        longitudeText = String(format: "%.6f", fallbackImage.longitude)
      } else {
        latitudeText = ""
        longitudeText = ""
      }
    }
  }

  private var canSave: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && (isEditing || previewImage != nil)
  }

  private var errorBinding: Binding<Bool> {
    Binding(
      get: { errorMessage != nil },
      set: { if !$0 { errorMessage = nil } }
    )
  }

  private func loadExistingIfNeeded() {
    guard case .edit(let image) = mode else { return }
    title = image.title
    tag = image.tag
    description = image.description
    locationName = image.locationName ?? ""
    if image.url.isFileURL, let data = try? Data(contentsOf: image.url) {
      previewImage = UIImage(data: data)
      loadLocationFromFileData(data, fallbackImage: image)
    } else {
      hasEmbeddedLocation = image.hasEmbeddedLocation
      if image.hasLocation {
        latitudeText = String(format: "%.6f", image.latitude)
        longitudeText = String(format: "%.6f", image.longitude)
      }
    }
  }

  private func resolvedCoordinates(forExisting existing: GalleryImage) -> (latitude: Double, longitude: Double) {
    if hasEmbeddedLocation {
      return (
        Double(latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? existing.latitude,
        Double(longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? existing.longitude
      )
    }
    return (
      Double(latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
      Double(longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    )
  }

  private func save() {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedLocation = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
    let location = trimmedLocation.isEmpty ? nil : trimmedLocation

    isSaving = true

    switch mode {
    case .add:
      guard let previewImage else {
        errorMessage = "请选择一张图片"
        isSaving = false
        return
      }
      let imageData = pendingImageData ?? previewImage.jpegData(compressionQuality: 0.85)
      guard let imageData else {
        errorMessage = "请选择一张图片"
        isSaving = false
        return
      }
      let latitude = Double(latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
      let longitude = Double(longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
      do {
        try galleryStore.addImage(
          imageData: imageData,
          title: trimmedTitle,
          tag: tag,
          description: trimmedDescription.isEmpty ? "用户上传的图片" : trimmedDescription,
          latitude: latitude,
          longitude: longitude,
          locationName: location,
          hasEmbeddedLocation: hasEmbeddedLocation
        )
        dismiss()
      } catch {
        errorMessage = error.localizedDescription
      }

    case .edit(let existing):
      let coords = resolvedCoordinates(forExisting: existing)
      let updated = GalleryImage(
        id: existing.id,
        title: trimmedTitle,
        tag: tag,
        description: trimmedDescription.isEmpty ? existing.description : trimmedDescription,
        url: existing.url,
        latitude: coords.latitude,
        longitude: coords.longitude,
        locationName: location,
        hasEmbeddedLocation: hasEmbeddedLocation,
        category: GalleryImageCategory.from(tag: tag),
        isPublished: existing.isPublished,
        isCloudSynced: pendingImageData == nil ? existing.isCloudSynced : false,
        engagementKey: existing.engagementKey,
        folderId: existing.folderId,
        mediaType: existing.mediaType,
        mediaURL: existing.mediaURL
      )

      if let pendingImageData {
        do {
          try galleryStore.replaceImageFile(existing, with: pendingImageData)
        } catch {
          errorMessage = error.localizedDescription
          isSaving = false
          return
        }
      }

      galleryStore.updateImage(updated)
      dismiss()
    }

    isSaving = false
  }
}
