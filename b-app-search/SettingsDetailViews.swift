//
//  SettingsDetailViews.swift
//  b-app-search
//

import SwiftUI

struct NotificationSettingsView: View {
  @AppStorage(AppSettings.pushNotificationsEnabledKey) private var pushEnabled = false
  @AppStorage(AppSettings.notifyCommentsKey) private var notifyComments = false
  @AppStorage(AppSettings.notifyLikesKey) private var notifyLikes = false
  @AppStorage(AppSettings.notifyFollowsKey) private var notifyFollows = false
  @AppStorage(AppSettings.notifySharesKey) private var notifyShares = false

  var body: some View {
    Form {
      Section {
        Toggle("推送通知", isOn: $pushEnabled)
      } footer: {
        Text("开启后可接收 App 推送；具体类型可在下方单独设置。")
      }

      Section {
        Toggle("评论", isOn: $notifyComments)
          .disabled(!pushEnabled)
        Toggle("点赞", isOn: $notifyLikes)
          .disabled(!pushEnabled)
        Toggle("新关注", isOn: $notifyFollows)
          .disabled(!pushEnabled)
        Toggle("分享", isOn: $notifyShares)
          .disabled(!pushEnabled)
      } header: {
        Text("通知类型")
      } footer: {
        Text("默认全部关闭。演示环境下通知不会真正发送到系统。")
      }
    }
    .navigationTitle("通知")
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct LanguageSettingsView: View {
  @AppStorage(AppSettings.languageKey) private var languageRaw = AppLanguage.system.rawValue

  private var selection: AppLanguage {
    AppLanguage(rawValue: languageRaw) ?? .system
  }

  var body: some View {
    Form {
      Section {
        ForEach(AppLanguage.allCases) { language in
          Button {
            languageRaw = language.rawValue
            AppSettings.setLanguage(language)
          } label: {
            HStack {
              Text(language.title)
                .foregroundStyle(.primary)
              Spacer()
              if selection == language {
                Image(systemName: "checkmark")
                  .font(.body.weight(.semibold))
                  .foregroundStyle(Color.accentColor)
              }
            }
          }
        }
      } footer: {
        Text("语言偏好会保存在本地。完整界面翻译将在后续版本提供。")
      }
    }
    .navigationTitle("语言")
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct AppearanceSettingsView: View {
  @AppStorage(AppSettings.appearanceKey) private var appearanceRaw = AppAppearance.system.rawValue

  private var selection: AppAppearance {
    AppAppearance(rawValue: appearanceRaw) ?? .system
  }

  var body: some View {
    Form {
      Section {
        ForEach(AppAppearance.allCases) { appearance in
          Button {
            appearanceRaw = appearance.rawValue
            AppSettings.setAppearance(appearance)
          } label: {
            HStack {
              Text(appearance.title)
                .foregroundStyle(.primary)
              Spacer()
              if selection == appearance {
                Image(systemName: "checkmark")
                  .font(.body.weight(.semibold))
                  .foregroundStyle(Color.accentColor)
              }
            }
          }
        }
      } footer: {
        Text("选择 App 的外观模式，或跟随系统设置。")
      }
    }
    .navigationTitle("外观")
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct SkinSettingsView: View {
  @AppStorage(AppSettings.skinKey) private var skinRaw = AppSkin.default.rawValue

  private var selection: AppSkin {
    AppSkin(rawValue: skinRaw) ?? .default
  }

  var body: some View {
    Form {
      Section {
        ForEach(AppSkin.allCases) { skin in
          Button {
            skinRaw = skin.rawValue
            AppSettings.setSkin(skin)
          } label: {
            SkinOptionRow(skin: skin, isSelected: selection == skin)
          }
          .buttonStyle(.plain)
        }
      } header: {
        Text("预制皮肤")
      } footer: {
        Text("皮肤同时切换代码样式（颜色、圆角等）与图片资源槽位。图片命名：Skin_槽位_皮肤，例如 Skin_homeHero_fresh；缺失时回退到共享图或代码生成图。")
      }

      Section {
        Image(skinAsset: .settingsBanner, skin: selection)
          .resizable()
          .scaledToFill()
          .frame(height: 120)
          .clipShape(RoundedRectangle(cornerRadius: selection.tokens.cardCornerRadius, style: .continuous))
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
          .listRowBackground(Color.clear)
      } header: {
        Text("预览")
      }
    }
    .navigationTitle("皮肤")
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct SkinOptionRow: View {
  let skin: AppSkin
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: skin.systemImage)
        .font(.title3.weight(.semibold))
        .foregroundStyle(skin.tokens.accent)
        .frame(width: 36, height: 36)
        .background(skin.tokens.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        Text(skin.title)
          .font(.body.weight(.semibold))
          .foregroundStyle(.primary)
        Text(skin.subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)

        HStack(spacing: 6) {
          ForEach(Array(skin.tokens.previewSwatches.enumerated()), id: \.offset) { _, color in
            Circle()
              .fill(color)
              .frame(width: 12, height: 12)
              .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
          }
        }
        .padding(.top, 2)
      }

      Spacer(minLength: 0)

      if isSelected {
        Image(systemName: "checkmark.circle.fill")
          .font(.title3)
          .foregroundStyle(skin.tokens.accent)
      }
    }
    .padding(.vertical, 4)
    .contentShape(Rectangle())
  }
}

struct MapAppSettingsView: View {
  @AppStorage(AppSettings.preferredMapAppKey) private var mapAppRaw = PreferredMapApp.apple.rawValue

  private var selection: PreferredMapApp {
    PreferredMapApp(rawValue: mapAppRaw) ?? .apple
  }

  var body: some View {
    Form {
      Section {
        ForEach(PreferredMapApp.allCases) { mapApp in
          Button {
            mapAppRaw = mapApp.rawValue
            AppSettings.setPreferredMapApp(mapApp)
          } label: {
            HStack {
              Text(mapApp.title)
                .foregroundStyle(.primary)
              Spacer()
              if selection == mapApp {
                Image(systemName: "checkmark")
                  .font(.body.weight(.semibold))
                  .foregroundStyle(Color.accentColor)
              }
            }
          }
        }
      } footer: {
        Text("在 App 外打开地点导航时，将优先使用所选地图应用。")
      }
    }
    .navigationTitle("地图")
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct SecuritySettingsView: View {
  @AppStorage(AppSettings.passcodeEnabledKey) private var passcodeEnabled = false
  @AppStorage(AppSettings.faceIDEnabledKey) private var faceIDEnabled = false

  @State private var showCreatePasscode = false
  @State private var showDisablePasscode = false
  @State private var securityError: String?

  private var biometryTitle: String {
    AppSecurityService.biometryTitle
  }

  var body: some View {
    Form {
      Section {
        if passcodeEnabled && AppSecurityService.hasStoredPasscode {
          LabeledContent("App 密码") {
            Text("已开启")
              .foregroundStyle(.secondary)
          }

          NavigationLink("更改密码") {
            PasscodeSetupView(mode: .change) { success in
              if success { passcodeEnabled = AppSecurityService.isPasscodeEnabled }
            }
          }

          Button("关闭密码", role: .destructive) {
            showDisablePasscode = true
          }
        } else {
          Button("打开密码") {
            showCreatePasscode = true
          }
        }
      } header: {
        Text("密码")
      } footer: {
        Text("开启后，可在打开 App 时使用密码保护。密码保存在本机 Keychain。")
      }

      Section {
        Toggle("使用 \(biometryTitle) 解锁", isOn: faceIDBinding)
          .disabled(!passcodeEnabled || !AppSecurityService.isBiometryAvailable)
      } header: {
        Text(biometryTitle)
      } footer: {
        if !AppSecurityService.isBiometryAvailable {
          Text("当前设备不支持 \(biometryTitle)。")
        } else if !passcodeEnabled {
          Text("需先开启 App 密码后，才能使用 \(biometryTitle) 解锁。")
        } else {
          Text("开启后，可使用 \(biometryTitle) 代替输入密码。")
        }
      }
    }
    .navigationTitle("安全")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      syncSecurityState()
    }
    .sheet(isPresented: $showCreatePasscode) {
      NavigationStack {
        PasscodeSetupView(mode: .create) { success in
          showCreatePasscode = false
          if success { syncSecurityState() }
        }
      }
    }
    .sheet(isPresented: $showDisablePasscode) {
      NavigationStack {
        PasscodeSetupView(mode: .disable) { success in
          showDisablePasscode = false
          if success { syncSecurityState() }
        }
      }
    }
    .alert("无法更新安全设置", isPresented: securityErrorBinding) {
      Button("确定", role: .cancel) { securityError = nil }
    } message: {
      Text(securityError ?? "")
    }
  }

  private var faceIDBinding: Binding<Bool> {
    Binding(
      get: { faceIDEnabled },
      set: { newValue in
        Task {
          let result = await AppSecurityService.setFaceIDEnabled(newValue)
          await MainActor.run {
            switch result {
            case .success:
              faceIDEnabled = AppSecurityService.isFaceIDEnabled
            case .failure(let error):
              faceIDEnabled = AppSecurityService.isFaceIDEnabled
              securityError = error.localizedDescription
            }
          }
        }
      }
    )
  }

  private var securityErrorBinding: Binding<Bool> {
    Binding(
      get: { securityError != nil },
      set: { if !$0 { securityError = nil } }
    )
  }

  private func syncSecurityState() {
    passcodeEnabled = AppSecurityService.isPasscodeEnabled
    faceIDEnabled = AppSecurityService.isFaceIDEnabled
  }
}

struct PasscodeSetupView: View {
  let mode: PasscodeSetupMode
  var onComplete: (Bool) -> Void = { _ in }

  @Environment(\.dismiss) private var dismiss

  @State private var passcode = ""
  @State private var confirmPasscode = ""
  @State private var currentPasscode = ""
  @State private var errorMessage: String?

  var body: some View {
    Form {
      if mode == .change {
        Section {
          SecureField("当前密码", text: $currentPasscode)
            .keyboardType(.numberPad)
        }
      }

      if mode == .create || mode == .change {
        Section {
          SecureField("新密码", text: $passcode)
            .keyboardType(.numberPad)
          SecureField("确认密码", text: $confirmPasscode)
            .keyboardType(.numberPad)
        } footer: {
          Text("密码至少 4 位数字。")
        }
      }

      if mode == .disable {
        Section {
          SecureField("当前密码", text: $currentPasscode)
            .keyboardType(.numberPad)
        } footer: {
          Text("关闭密码后，\(AppSecurityService.biometryTitle) 解锁也会同时关闭。")
        }
      }

      Section {
        Button(primaryButtonTitle) {
          submit()
        }
        .frame(maxWidth: .infinity, alignment: .center)
      }
    }
    .navigationTitle(navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("取消") {
          onComplete(false)
          dismiss()
        }
      }
    }
    .alert("操作失败", isPresented: errorBinding) {
      Button("确定", role: .cancel) { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "")
    }
  }

  private var navigationTitle: String {
    switch mode {
    case .create: return "设置密码"
    case .change: return "更改密码"
    case .disable: return "关闭密码"
    }
  }

  private var primaryButtonTitle: String {
    switch mode {
    case .create: return "打开密码"
    case .change: return "保存新密码"
    case .disable: return "关闭密码"
    }
  }

  private var errorBinding: Binding<Bool> {
    Binding(
      get: { errorMessage != nil },
      set: { if !$0 { errorMessage = nil } }
    )
  }

  private func submit() {
    switch mode {
    case .create:
      guard passcode.count >= 4, passcode.allSatisfy(\.isNumber) else {
        errorMessage = SecurityAuthError.invalidPasscode.localizedDescription
        return
      }
      guard passcode == confirmPasscode else {
        errorMessage = SecurityAuthError.passcodeMismatch.localizedDescription
        return
      }
      guard AppSecurityService.setPasscode(passcode) else {
        errorMessage = SecurityAuthError.invalidPasscode.localizedDescription
        return
      }
      onComplete(true)
      dismiss()

    case .change:
      guard AppSecurityService.verifyPasscode(currentPasscode) else {
        errorMessage = "当前密码不正确。"
        return
      }
      guard passcode.count >= 4, passcode.allSatisfy(\.isNumber) else {
        errorMessage = SecurityAuthError.invalidPasscode.localizedDescription
        return
      }
      guard passcode == confirmPasscode else {
        errorMessage = SecurityAuthError.passcodeMismatch.localizedDescription
        return
      }
      guard AppSecurityService.setPasscode(passcode) else {
        errorMessage = SecurityAuthError.invalidPasscode.localizedDescription
        return
      }
      onComplete(true)
      dismiss()

    case .disable:
      guard AppSecurityService.disablePasscode(confirmCode: currentPasscode) else {
        errorMessage = "当前密码不正确。"
        return
      }
      onComplete(true)
      dismiss()
    }
  }
}

struct LegalDocumentView: View {
  enum DocumentType {
    case privacy
    case terms

    var title: String {
      switch self {
      case .privacy: return "隐私政策"
      case .terms: return "服务条款"
      }
    }

    var bodyText: String {
      switch self {
      case .privacy:
        return """
        我们重视您的隐私。本应用会在本地存储您上传的图片、个人资料与互动数据；仅在您明确开启云同步或分享功能时，才会将相关内容用于对外展示。

        我们可能收集的信息包括：昵称、邮箱、头像、图片元数据（标题、标签、位置等）以及点赞、评论等互动记录。

        您可以在「个人信息」中管理主页展示项（邮箱、电话、年龄、位置等），默认均不对外展示。

        如需删除本地数据，可卸载 App 或在图片管理中删除相应内容。如有疑问，请联系 support@b-app-search.example.com。
        """
      case .terms:
        return """
        使用 b-app-search 即表示您同意遵守以下条款：

        1. 您应确保上传的内容不侵犯他人权益，并符合当地法律法规。
        2. 已分享的图片可能被其他用户浏览、点赞与评论。
        3. 我们保留在必要时限制或移除违规内容的权利。
        4. 本应用部分功能为演示用途，正式服务条款以后续公布版本为准。

        继续使用即视为接受更新后的条款。
        """
      }
    }
  }

  let document: DocumentType

  var body: some View {
    ScrollView {
      Text(document.bodyText)
        .font(.body)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle(document.title)
    .navigationBarTitleDisplayMode(.inline)
  }
}
