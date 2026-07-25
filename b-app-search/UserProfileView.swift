//
//  UserProfileView.swift
//  b-app-search
//

import SwiftUI

struct PersonalAccountSettingsView: View {
  @EnvironmentObject private var galleryStore: GalleryStore
  @Environment(\.dismiss) private var dismiss

  @AppStorage(UserSession.isLoggedInKey) private var isLoggedIn = false
  @AppStorage(UserSession.userNicknameKey) private var userNickname = ""
  @AppStorage(UserSession.userBioKey) private var userBio = ""
  @AppStorage(UserSession.userEmailKey) private var userEmail = ""
  @AppStorage(AppSettings.shareLocationOnProfileKey) private var shareLocationOnProfile = false
  @AppStorage(AppSettings.profileLocationNameKey) private var profileLocationName = ""
  @AppStorage(AppSettings.showEmailOnProfileKey) private var showEmailOnProfile = false
  @AppStorage(AppSettings.showPhoneOnProfileKey) private var showPhoneOnProfile = false
  @AppStorage(AppSettings.showAgeOnProfileKey) private var showAgeOnProfile = false
  @AppStorage(UserSession.userPhoneKey) private var userPhone = ""
  @AppStorage(UserSession.userAgeKey) private var userAge = ""

  @State private var showLogoutConfirm = false

  var body: some View {
    Form {
      Section {
        profileNavigationRow(field: .nickname, value: displayNickname)
        profileNavigationRow(field: .email, value: emailDisplayValue)
        profileNavigationRow(field: .phone, value: phoneDisplayValue)
        profileNavigationRow(field: .age, value: ageDisplayValue)
        profileNavigationRow(field: .bio, value: bioDisplayValue)
      }

      Section {
        NavigationLink {
          ChangePasswordView()
        } label: {
          Text("修改密码")
        }
      }

      Section {
        Toggle("展示邮箱", isOn: $showEmailOnProfile)
        Toggle("展示电话", isOn: $showPhoneOnProfile)
        Toggle("展示年龄", isOn: $showAgeOnProfile)
        Toggle("展示位置", isOn: $shareLocationOnProfile)
        if shareLocationOnProfile {
          TextField("所在城市", text: $profileLocationName)
        }
      } header: {
        Text("主页展示")
      } footer: {
        Text("邮箱、电话、年龄、位置默认均不对外展示，开启后其他用户可在你的个人主页看到。")
      }

      Section {
        Toggle("个人图片共享", isOn: $galleryStore.personalImagesSharingEnabled)
      } footer: {
        Text("关闭后，你已发布的图片将不会在首页和共享图片页展示；重新开启后恢复展示。")
      }

      Section {
        Button("退出登录", role: .destructive) {
          showLogoutConfirm = true
        }
        .frame(maxWidth: .infinity, alignment: .center)
      }
    }
    .navigationTitle("个人设置")
    .navigationBarTitleDisplayMode(.inline)
    .confirmationDialog("确定退出登录？", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
      Button("退出登录", role: .destructive) {
        UserSession.signOut()
        isLoggedIn = false
        dismiss()
      }
      Button("取消", role: .cancel) {}
    }
  }

  private func profileNavigationRow(field: ProfileEditableField, value: String) -> some View {
    NavigationLink {
      ProfileFieldEditorView(field: field)
    } label: {
      HStack {
        Text(field.title)
        Spacer()
        Text(value)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }

  private var displayNickname: String {
    let trimmed = userNickname.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "用户" : trimmed
  }

  private var emailDisplayValue: String {
    let trimmed = userEmail.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "未设置" : trimmed
  }

  private var bioDisplayValue: String {
    let trimmed = userBio.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "未设置" : trimmed
  }

  private var phoneDisplayValue: String {
    let trimmed = userPhone.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "未设置" : trimmed
  }

  private var ageDisplayValue: String {
    let trimmed = userAge.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "未设置" : trimmed
  }
}

struct PersonalAccountSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      PersonalAccountSettingsView()
        .environmentObject(GalleryStore.shared)
    }
  }
}
