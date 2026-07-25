//
//  ChangePasswordView.swift
//  b-app-search
//

import SwiftUI

struct ChangePasswordView: View {
  @State private var currentPassword = ""
  @State private var newPassword = ""
  @State private var confirmPassword = ""
  @State private var passwordSaved = false
  @State private var passwordError: String?
  @State private var isUpdatingPassword = false

  var body: some View {
    Form {
      Section {
        SecureField("当前密码", text: $currentPassword)
        SecureField("新密码", text: $newPassword)
        SecureField("确认新密码", text: $confirmPassword)
      } footer: {
        Text("新密码至少 6 位。演示环境下修改仅保存在本地。")
      }

      Section {
        Button {
          changePassword()
        } label: {
          HStack {
            Spacer()
            if isUpdatingPassword {
              ProgressView()
            } else {
              Text("更新密码")
                .fontWeight(.semibold)
            }
            Spacer()
          }
        }
        .disabled(isUpdatingPassword)
      }
    }
    .navigationTitle("修改密码")
    .navigationBarTitleDisplayMode(.inline)
    .alert("密码已更新", isPresented: $passwordSaved) {
      Button("确定", role: .cancel) {
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
      }
    } message: {
      Text("演示环境：密码修改仅保存在本地。")
    }
    .alert("无法修改密码", isPresented: passwordErrorBinding) {
      Button("确定", role: .cancel) { passwordError = nil }
    } message: {
      Text(passwordError ?? "")
    }
  }

  private var passwordErrorBinding: Binding<Bool> {
    Binding(
      get: { passwordError != nil },
      set: { if !$0 { passwordError = nil } }
    )
  }

  private func changePassword() {
    guard !currentPassword.isEmpty else {
      passwordError = "请输入当前密码"
      return
    }
    guard newPassword.count >= 6 else {
      passwordError = "新密码至少 6 位"
      return
    }
    guard newPassword == confirmPassword else {
      passwordError = "两次输入的新密码不一致"
      return
    }

    isUpdatingPassword = true
    Task {
      do {
        try await BackendAPI.User.changePassword(current: currentPassword, newPassword: newPassword)
        await MainActor.run {
          passwordSaved = true
          isUpdatingPassword = false
        }
      } catch {
        await MainActor.run {
          passwordError = error.localizedDescription
          isUpdatingPassword = false
        }
      }
    }
  }
}

struct ChangePasswordView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      ChangePasswordView()
    }
  }
}
