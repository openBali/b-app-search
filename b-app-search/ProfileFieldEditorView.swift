//
//  ProfileFieldEditorView.swift
//  b-app-search
//

import SwiftUI

enum ProfileEditableField: String, Identifiable {
  case nickname
  case email
  case phone
  case age
  case bio

  var id: String { rawValue }

  var title: String {
    switch self {
    case .nickname: return "昵称"
    case .email: return "邮箱"
    case .phone: return "电话"
    case .age: return "年龄"
    case .bio: return "个人简介"
    }
  }

  var placeholder: String {
    switch self {
    case .nickname: return "请输入昵称"
    case .email: return "请输入邮箱"
    case .phone: return "请输入电话号码"
    case .age: return "请输入年龄"
    case .bio: return "介绍一下自己"
    }
  }
}

struct ProfileFieldEditorView: View {
  let field: ProfileEditableField

  @AppStorage(UserSession.userNicknameKey) private var userNickname = ""
  @AppStorage(UserSession.userBioKey) private var userBio = ""
  @AppStorage(UserSession.userEmailKey) private var userEmail = ""
  @AppStorage(UserSession.userPhoneKey) private var userPhone = ""
  @AppStorage(UserSession.userAgeKey) private var userAge = ""

  @Environment(\.dismiss) private var dismiss

  @State private var text = ""
  @State private var isSaving = false
  @State private var saveError: String?
  @State private var didSave = false

  var body: some View {
    Form {
      Section {
        switch field {
        case .nickname:
          TextField(field.placeholder, text: $text)
        case .email:
          TextField(field.placeholder, text: $text)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
        case .phone:
          TextField(field.placeholder, text: $text)
            .keyboardType(.phonePad)
        case .age:
          TextField(field.placeholder, text: $text)
            .keyboardType(.numberPad)
        case .bio:
          TextField(field.placeholder, text: $text, axis: .vertical)
            .lineLimit(4...8)
        }
      } footer: {
        switch field {
        case .nickname:
          Text("昵称将显示在个人主页与评论中。")
        case .phone:
          Text("电话号码默认不在个人主页展示，可在「主页展示」中开启。")
        case .age:
          Text("年龄默认不在个人主页展示，可在「主页展示」中开启。")
        default:
          EmptyView()
        }
      }
    }
    .navigationTitle(field.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("存储") {
          save()
        }
        .disabled(isSaving || !canSave)
      }
    }
    .onAppear {
      text = currentStoredValue
    }
    .alert("已保存", isPresented: $didSave) {
      Button("确定") { dismiss() }
    }
    .alert("无法保存", isPresented: saveErrorBinding) {
      Button("确定", role: .cancel) { saveError = nil }
    } message: {
      Text(saveError ?? "")
    }
  }

  private var currentStoredValue: String {
    switch field {
    case .nickname: return userNickname
    case .email: return userEmail
    case .phone: return userPhone
    case .age: return userAge
    case .bio: return userBio
    }
  }

  private var canSave: Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if field == .nickname {
      return !trimmed.isEmpty
    }
    return trimmed != currentStoredValue.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var saveErrorBinding: Binding<Bool> {
    Binding(
      get: { saveError != nil },
      set: { if !$0 { saveError = nil } }
    )
  }

  private func save() {
    let nickname = field == .nickname
      ? text.trimmingCharacters(in: .whitespacesAndNewlines)
      : userNickname.trimmingCharacters(in: .whitespacesAndNewlines)
    let bio = field == .bio
      ? text.trimmingCharacters(in: .whitespacesAndNewlines)
      : userBio.trimmingCharacters(in: .whitespacesAndNewlines)
    let email = field == .email
      ? text.trimmingCharacters(in: .whitespacesAndNewlines)
      : userEmail.trimmingCharacters(in: .whitespacesAndNewlines)
    let phone = field == .phone
      ? text.trimmingCharacters(in: .whitespacesAndNewlines)
      : userPhone.trimmingCharacters(in: .whitespacesAndNewlines)
    let age = field == .age
      ? text.trimmingCharacters(in: .whitespacesAndNewlines)
      : userAge.trimmingCharacters(in: .whitespacesAndNewlines)

    guard field != .nickname || !nickname.isEmpty else { return }

    isSaving = true
    Task {
      do {
        if field == .phone || field == .age {
          UserSession.updateContact(phone: phone, age: age)
          await MainActor.run {
            userPhone = phone
            userAge = age
            isSaving = false
            didSave = true
          }
        } else {
          _ = try await BackendAPI.User.updateProfile(nickname: nickname, bio: bio, email: email)
          UserSession.updateProfile(nickname: nickname, bio: bio, email: email)
          UserSession.updateContact(phone: userPhone, age: userAge)
          await MainActor.run {
            userNickname = nickname
            userBio = bio
            userEmail = email
            isSaving = false
            didSave = true
          }
        }
      } catch {
        await MainActor.run {
          saveError = error.localizedDescription
          isSaving = false
        }
      }
    }
  }
}

struct ProfileFieldEditorView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      ProfileFieldEditorView(field: .nickname)
    }
  }
}
