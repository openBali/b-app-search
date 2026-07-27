//
//  SettingsView.swift
//  b-app-search
//

import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var galleryStore: GalleryStore
  @EnvironmentObject private var tagStore: ImageTagStore

  @AppStorage(UserSession.isLoggedInKey) private var isLoggedIn = false
  @AppStorage(UserSession.userNicknameKey) private var userNickname = ""
  @AppStorage(AppSettings.appearanceKey) private var appearanceRaw = AppAppearance.system.rawValue
  @AppStorage(AppSettings.skinKey) private var skinRaw = AppSkin.default.rawValue
  @AppStorage(AppSettings.languageKey) private var languageRaw = AppLanguage.system.rawValue
  @AppStorage(AppSettings.preferredMapAppKey) private var mapAppRaw = PreferredMapApp.apple.rawValue
  @AppStorage(AppSettings.membershipTierKey) private var membershipTierRaw = MembershipTier.default.rawValue

  @State private var showLogin = false
  @State private var showMembershipSwitch = false

  private var appearanceLabel: String {
    AppAppearance(rawValue: appearanceRaw)?.title ?? AppAppearance.system.title
  }

  private var skinLabel: String {
    AppSkin(rawValue: skinRaw)?.title ?? AppSkin.default.title
  }

  private var languageLabel: String {
    AppLanguage(rawValue: languageRaw)?.title ?? AppLanguage.system.title
  }

  private var mapAppLabel: String {
    PreferredMapApp(rawValue: mapAppRaw)?.title ?? PreferredMapApp.apple.title
  }

  private var membershipLabel: String {
    (MembershipTier(rawValue: membershipTierRaw) ?? .default).title
  }

  private var displayNickname: String {
    let trimmed = userNickname.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "用户" : trimmed
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        Group {
          if isLoggedIn {
            NavigationLink {
              PersonalHomePageView(identity: .currentUser)
            } label: {
              SettingsProfileHeaderContent(
                isLoggedIn: true,
                displayNickname: displayNickname,
                membershipLabel: membershipLabel
              )
            }
            .buttonStyle(.plain)
          } else {
            Button(action: handleProfileHeaderTap) {
              SettingsProfileHeaderContent(
                isLoggedIn: false,
                displayNickname: displayNickname,
                membershipLabel: membershipLabel
              )
            }
            .buttonStyle(.plain)
          }
        }

        Form {
          Section {
            Button {
              showMembershipSwitch = true
            } label: {
              HStack {
                Label("会员", systemImage: "crown.fill")
                Spacer()
                Text(membershipLabel)
                  .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.tertiary)
              }
            }
            .foregroundStyle(.primary)

            if isLoggedIn {
              NavigationLink {
                PersonalAccountSettingsView()
              } label: {
                Label("个人设置", systemImage: "person.crop.circle")
              }
            } else {
              Button {
                showLogin = true
              } label: {
                Label("登录", systemImage: "person.crop.circle.badge.plus")
              }
            }
          } header: {
            Text("账号")
          } footer: {
            Text(
              isLoggedIn
                ? "充值包月或包年后将自动升级为高级会员；资料与展示偏好请在个人设置中管理。"
                : "可查看会员充值方案；登录后可编辑资料与偏好设置。"
            )
          }

          Section {
            NavigationLink {
              NotificationSettingsView()
            } label: {
              Label("通知", systemImage: "bell.badge.fill")
            }

            NavigationLink {
              SecuritySettingsView()
            } label: {
              Label("安全", systemImage: "lock.shield.fill")
            }

            NavigationLink {
              ActivityCenterView()
            } label: {
              Label("活动", systemImage: "gift.fill")
            }
          }

          Section {
            NavigationLink {
              AppearanceSettingsView()
            } label: {
              HStack {
                Label("外观", systemImage: "circle.lefthalf.filled")
                Spacer()
                Text(appearanceLabel)
                  .foregroundStyle(.secondary)
              }
            }

            NavigationLink {
              SkinSettingsView()
            } label: {
              HStack {
                Label("皮肤", systemImage: "paintpalette.fill")
                Spacer()
                Text(skinLabel)
                  .foregroundStyle(.secondary)
              }
            }

            NavigationLink {
              LanguageSettingsView()
            } label: {
              HStack {
                Label("语言", systemImage: "globe")
                Spacer()
                Text(languageLabel)
                  .foregroundStyle(.secondary)
              }
            }

            NavigationLink {
              MapAppSettingsView()
            } label: {
              HStack {
                Label("地图", systemImage: "map.fill")
                Spacer()
                Text(mapAppLabel)
                  .foregroundStyle(.secondary)
              }
            }
          }

          Section {
            NavigationLink {
              AlbumDataSettingsView()
            } label: {
              Label("相册同步", systemImage: "photo.on.rectangle.angled")
            }

            NavigationLink {
              PrivateFolderManageView()
            } label: {
              Label("私人文件夹", systemImage: "folder.fill")
            }

            NavigationLink {
              ImageTagSettingsView()
            } label: {
              HStack {
                Label("图片标签", systemImage: "tag.fill")
                Spacer()
                Text("\(tagStore.mergedTags().count)")
                  .foregroundStyle(.secondary)
              }
            }
          } header: {
            Text("相册与数据")
          } footer: {
            Text("同步、数据统计等详细选项请在「相册同步」中管理。")
          }

          Section {
            NavigationLink {
              LegalDocumentView(document: .privacy)
            } label: {
              Text("隐私政策")
            }

            NavigationLink {
              LegalDocumentView(document: .terms)
            } label: {
              Text("服务条款")
            }
          } header: {
            Text("法律信息")
          }

          Section {
            LabeledContent("版本") {
              Text(appVersion)
                .foregroundStyle(.secondary)
            }
          }
        }
        .scrollContentBackground(.hidden)
        .padding(.top, -10)
      }
      .background(Color(.systemGroupedBackground).ignoresSafeArea())
      .navigationBarHidden(true)
      .sheet(isPresented: $showLogin) {
        LoginView(isLoggedIn: $isLoggedIn)
      }
      .sheet(isPresented: $showMembershipSwitch) {
        MembershipUpgradeSheet(membershipTierRaw: $membershipTierRaw)
          .presentationDetents([.height(300)])
          .presentationDragIndicator(.visible)
      }
    }
  }

  private func handleProfileHeaderTap() {
    if isLoggedIn {
      return
    }
    showLogin = true
  }

  private var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    return "\(version) (\(build))"
  }
}

/// 相册同步与数据统计的专门页面（设置页仅保留三个入口）。
struct AlbumDataSettingsView: View {
  @EnvironmentObject private var galleryStore: GalleryStore

  @AppStorage(AppSettings.iosPhotoLibrarySyncEnabledKey) private var iosPhotoLibrarySyncEnabled = false
  @AppStorage(AppSettings.iosPhotoLibrarySyncActiveKey) private var iosPhotoLibrarySyncActive = false

  @State private var syncErrorMessage: String?

  var body: some View {
    Form {
      Section {
        Toggle("同步到 iOS 相册", isOn: $iosPhotoLibrarySyncEnabled)
          .onChange(of: iosPhotoLibrarySyncEnabled) { enabled in
            AppSettings.setIOSPhotoLibrarySyncEnabled(enabled)
            if !enabled {
              iosPhotoLibrarySyncActive = false
            }
          }

        if iosPhotoLibrarySyncEnabled {
          LabeledContent("首页同步开关") {
            Text(iosPhotoLibrarySyncActive ? "已打开" : "已关闭")
              .foregroundStyle(.secondary)
          }

          Button("立即同步全部图片") {
            performFullSync()
          }
          .disabled(!iosPhotoLibrarySyncActive)
        }
      } header: {
        Text("相册同步")
      } footer: {
        Text("开启后，图片会按 App 内文件夹写入 iOS 相簿。首页同步开关可在首页文件夹栏中切换。")
      }

      Section {
        LabeledContent("私人文件夹") {
          Text("\(galleryStore.manageablePrivateFolders.count) 个")
            .foregroundStyle(.secondary)
        }

        LabeledContent("我的图片") {
          Text("\(galleryStore.userImages.count) 张")
            .foregroundStyle(.secondary)
        }

        LabeledContent("已发布") {
          Text("\(galleryStore.userImages.filter(\.isPublished).count) 张")
            .foregroundStyle(.secondary)
        }
      } header: {
        Text("数据概览")
      }
    }
    .navigationTitle("相册同步")
    .navigationBarTitleDisplayMode(.inline)
    .alert("同步失败", isPresented: syncErrorBinding) {
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

  private func performFullSync() {
    Task {
      do {
        try await IOSPhotoLibrarySyncService.shared.requestAuthorizationIfNeeded()
        try await IOSPhotoLibrarySyncService.shared.syncAll(from: galleryStore)
      } catch {
        syncErrorMessage = error.localizedDescription
      }
    }
  }
}

/// 会员充值弹窗：选择包月 / 包年，成功后自动升级为高级会员（演示）。
private struct MembershipUpgradeSheet: View {
  @Binding var membershipTierRaw: String
  @Environment(\.dismiss) private var dismiss

  private var isPremium: Bool {
    (MembershipTier(rawValue: membershipTierRaw) ?? .default).isPremium
  }

  var body: some View {
    VStack(spacing: 18) {
      Text("敬请期待")
        .font(.title3.weight(.semibold))
        .padding(.top, 28)

      Text(isPremium ? "你已是高级会员，续费后保持高级会员" : "充值成功后将自动升级为高级会员")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)

      VStack(spacing: 10) {
        ForEach(MembershipPlan.allCases) { plan in
          Button {
            activate(plan)
          } label: {
            Text(plan.title)
              .font(.body.weight(.semibold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 24)

      Spacer(minLength: 0)

      Button("关闭") {
        dismiss()
      }
      .font(.body.weight(.semibold))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .padding(.horizontal, 24)
      .padding(.bottom, 20)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemBackground))
  }

  private func activate(_ plan: MembershipPlan) {
    AppSettings.activateMembership(plan: plan)
    membershipTierRaw = MembershipTier.premium.rawValue
    dismiss()
  }
}

private struct SettingsProfileHeaderContent: View {
  let isLoggedIn: Bool
  let displayNickname: String
  var membershipLabel: String = MembershipTier.default.title

  private let avatarSize: CGFloat = 80
  private let bannerHeight: CGFloat = 88

  private var bannerColor: Color {
    UserAvatarView.accentColor(for: isLoggedIn ? displayNickname : "访客")
  }

  var body: some View {
    VStack(spacing: 0) {
      bannerColor
        .frame(height: bannerHeight)
        .frame(maxWidth: .infinity)

      VStack(spacing: 6) {
        UserAvatarView(
          name: isLoggedIn ? displayNickname : "访客",
          size: avatarSize,
          useSessionAvatar: isLoggedIn
        )
        .overlay {
          Circle()
            .strokeBorder(Color(.systemGroupedBackground), lineWidth: 4)
        }
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)

        Text(isLoggedIn ? displayNickname : "未登录")
          .font(.title3.weight(.semibold))
          .foregroundStyle(.primary)

        Text(membershipLabel)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color(red: 0.72, green: 0.52, blue: 0.18))
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(
            Color(red: 0.72, green: 0.52, blue: 0.18).opacity(0.12),
            in: Capsule()
          )

        Text(isLoggedIn ? "查看个人主页" : "登录后管理账号与偏好")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.top, -(avatarSize / 2))
      .padding(.bottom, 6)
      .frame(maxWidth: .infinity)
      .background(Color(.systemGroupedBackground))
    }
    .background(alignment: .top) {
      VStack(spacing: 0) {
        bannerColor
        Color(.systemGroupedBackground)
      }
      .ignoresSafeArea(edges: .top)
    }
  }
}

struct SettingsView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsView()
      .environmentObject(GalleryStore.shared)
      .environmentObject(ImageTagStore.shared)
  }
}
