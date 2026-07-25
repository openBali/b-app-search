//
//  PrivateFolderManageView.swift
//  b-app-search
//

import SwiftUI

struct PrivateFolderManageView: View {
  @EnvironmentObject private var galleryStore: GalleryStore

  @State private var editorMode: FolderEditorMode?
  @State private var folderPendingDeletion: GalleryFolder?
  @State private var mutationErrorMessage: String?

  var body: some View {
    List {
      Section {
        ForEach(galleryStore.manageablePrivateFolders) { folder in
          Button {
            editorMode = .edit(folder)
          } label: {
            FolderManageRow(
              folder: folder,
              imageCount: galleryStore.privateImageCount(inFolder: folder.id)
            )
          }
          .buttonStyle(.plain)
          .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if galleryStore.canDeleteFolder(id: folder.id) {
              Button(role: .destructive) {
                folderPendingDeletion = folder
              } label: {
                Label("删除", systemImage: "trash")
              }
            }
          }
        }
      } header: {
        Text("私人文件夹")
      } footer: {
        Text("系统文件夹（如「未分类」）不可删除，但可改名。删除自定义文件夹后，其中图片会移入「未分类」。")
      }
    }
    .navigationTitle("文件夹整理")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          editorMode = .create
        } label: {
          Image(systemName: "folder.badge.plus")
        }
        .accessibilityLabel("新建文件夹")
      }
    }
    .sheet(item: $editorMode) { mode in
      FolderEditorSheet(mode: mode) { result in
        handleEditorResult(result, for: mode)
      }
      .presentationDetents([.medium])
    }
    .alert("删除文件夹", isPresented: deleteConfirmationBinding) {
      Button("删除", role: .destructive) {
        if let folder = folderPendingDeletion {
          galleryStore.deleteFolder(id: folder.id)
        }
        folderPendingDeletion = nil
      }
      Button("取消", role: .cancel) {
        folderPendingDeletion = nil
      }
    } message: {
      if let folder = folderPendingDeletion {
        let count = galleryStore.privateImageCount(inFolder: folder.id)
        if count > 0 {
          Text("删除「\(folder.name)」后，\(count) 张私人图片将移入「未分类」。")
        } else {
          Text("确定删除「\(folder.name)」吗？")
        }
      }
    }
    .alert("操作失败", isPresented: mutationErrorBinding) {
      Button("确定", role: .cancel) { mutationErrorMessage = nil }
    } message: {
      Text(mutationErrorMessage ?? "")
    }
  }

  private var deleteConfirmationBinding: Binding<Bool> {
    Binding(
      get: { folderPendingDeletion != nil },
      set: { if !$0 { folderPendingDeletion = nil } }
    )
  }

  private var mutationErrorBinding: Binding<Bool> {
    Binding(
      get: { mutationErrorMessage != nil },
      set: { if !$0 { mutationErrorMessage = nil } }
    )
  }

  private func handleEditorResult(_ result: FolderEditorResult, for mode: FolderEditorMode) {
    switch result {
    case .cancelled:
      break
    case .saved(let name):
      switch mode {
      case .create:
        if galleryStore.addFolder(name: name) == nil {
          mutationErrorMessage = "名称不能为空，且不能与已有文件夹重复。"
        }
      case .edit(let folder):
        if !galleryStore.renameFolder(id: folder.id, name: name) {
          mutationErrorMessage = "名称不能为空，且不能与已有文件夹重复。"
        }
      }
    }
  }
}

private struct FolderManageRow: View {
  let folder: GalleryFolder
  let imageCount: Int

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: folder.iconName)
        .font(.body.weight(.semibold))
        .foregroundStyle(Color(red: 0.28, green: 0.48, blue: 0.98))
        .frame(width: 34, height: 34)
        .background(Color(red: 0.28, green: 0.48, blue: 0.98).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(folder.name)
            .font(.body.weight(.semibold))
            .foregroundStyle(.primary)
          if folder.isSystem {
            Text("系统")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color(.tertiarySystemFill), in: Capsule())
          }
        }
        Text("\(imageCount) 张私人图片")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 4)
  }
}

private enum FolderEditorMode: Identifiable {
  case create
  case edit(GalleryFolder)

  var id: String {
    switch self {
    case .create: return "create"
    case .edit(let folder): return folder.id
    }
  }

  var title: String {
    switch self {
    case .create: return "新建文件夹"
    case .edit: return "编辑文件夹"
    }
  }

  var initialName: String {
    switch self {
    case .create: return ""
    case .edit(let folder): return folder.name
    }
  }
}

private enum FolderEditorResult {
  case cancelled
  case saved(String)
}

private struct FolderEditorSheet: View {
  let mode: FolderEditorMode
  let onComplete: (FolderEditorResult) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var name: String
  @FocusState private var isNameFocused: Bool

  init(mode: FolderEditorMode, onComplete: @escaping (FolderEditorResult) -> Void) {
    self.mode = mode
    self.onComplete = onComplete
    _name = State(initialValue: mode.initialName)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("文件夹名称", text: $name)
            .focused($isNameFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        } footer: {
          Text("名称不能与已有文件夹重复。")
        }
      }
      .navigationTitle(mode.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") {
            onComplete(.cancelled)
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") {
            onComplete(.saved(name))
            dismiss()
          }
          .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .onAppear {
        isNameFocused = true
      }
    }
  }
}

struct PrivateFolderManageView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      PrivateFolderManageView()
        .environmentObject(GalleryStore.shared)
    }
  }
}
