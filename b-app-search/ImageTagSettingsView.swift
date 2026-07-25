//
//  ImageTagSettingsView.swift
//  b-app-search
//

import SwiftUI

struct ImageTagSettingsView: View {
  @EnvironmentObject private var tagStore: ImageTagStore

  @State private var newTagName = ""
  @State private var showAddTagAlert = false
  @State private var duplicateTagAlert = false
  @State private var showSaveSuccess = false

  private var mergedPreviewTags: [String] {
    tagStore.mergedTags()
  }

  var body: some View {
    Form {
      Section {
        ForEach(ImageTagStore.defaultTags, id: \.self) { tag in
          Label(tag, systemImage: "tag.fill")
            .foregroundStyle(.primary)
        }
      } header: {
        Text("默认标签")
      } footer: {
        Text("内置标签始终展示在首页筛选栏，不可删除。")
      }

      Section {
        if tagStore.remoteTags.isEmpty {
          Text("暂无云端标签")
            .foregroundStyle(.secondary)
        } else {
          ForEach(tagStore.remoteTags, id: \.self) { tag in
            Label(tag, systemImage: "cloud.fill")
          }
        }

        Button {
          Task { await tagStore.fetchRemoteTags() }
        } label: {
          HStack {
            Label("从服务器刷新", systemImage: "arrow.clockwise")
            Spacer()
            if tagStore.isLoadingRemote {
              ProgressView()
            }
          }
        }
        .disabled(tagStore.isLoadingRemote)

        if let syncedAt = tagStore.lastRemoteSyncAt {
          LabeledContent("最近同步") {
            Text(syncedAt, style: .relative)
              .foregroundStyle(.secondary)
          }
        }
      } header: {
        Text("云端标签")
      } footer: {
        Text("由后台接口动态下发，与本地标签合并后用于首页筛选与图片编辑。")
      }

      Section {
        if tagStore.localTags.isEmpty {
          Text("还没有自定义标签")
            .foregroundStyle(.secondary)
        } else {
          ForEach(tagStore.localTags, id: \.self) { tag in
            Text(tag)
          }
          .onDelete(perform: tagStore.removeLocalTag(at:))
          .onMove(perform: tagStore.moveLocalTags)
        }

        Button {
          showAddTagAlert = true
        } label: {
          Label("添加标签", systemImage: "plus.circle.fill")
        }
      } header: {
        Text("我的标签")
      } footer: {
        Text("可添加、删除或拖动排序。保存后会尝试同步到服务器。")
      }

      Section {
        ForEach(mergedPreviewTags, id: \.self) { tag in
          Text(tag)
        }
      } header: {
        Text("合并预览")
      } footer: {
        Text("共 \(mergedPreviewTags.count) 个标签（默认 + 我的 + 云端，已去重）。")
      }

      if let error = tagStore.lastErrorMessage {
        Section {
          Text(error)
            .font(.caption)
            .foregroundStyle(.red)
        }
      }
    }
    .navigationTitle("图片标签")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        EditButton()
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("保存") {
          Task {
            await tagStore.saveLocalTagsToServer()
            if tagStore.lastErrorMessage == nil {
              showSaveSuccess = true
            }
          }
        }
        .disabled(tagStore.isSavingLocal || tagStore.localTags.isEmpty)
      }
    }
    .alert("添加标签", isPresented: $showAddTagAlert) {
      TextField("标签名称", text: $newTagName)
      Button("取消", role: .cancel) {
        newTagName = ""
      }
      Button("添加") {
        addTag()
      }
    } message: {
      Text("输入新的图片标签名称。")
    }
    .alert("标签已存在", isPresented: $duplicateTagAlert) {
      Button("确定", role: .cancel) {}
    } message: {
      Text("该标签已在默认、云端或本地列表中。")
    }
    .alert("已保存", isPresented: $showSaveSuccess) {
      Button("确定", role: .cancel) {}
    } message: {
      Text("自定义标签已同步到服务器。")
    }
  }

  private func addTag() {
    let added = tagStore.addLocalTag(newTagName)
    if !added {
      duplicateTagAlert = true
    }
    newTagName = ""
  }
}

struct ImageTagSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      ImageTagSettingsView()
        .environmentObject(ImageTagStore.shared)
    }
  }
}
