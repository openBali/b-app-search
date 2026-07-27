//
//  b_app_searchApp.swift
//  b-app-search
//
//  Created by Danis on 2026/5/6.
//

import SwiftUI

@main
struct b_app_searchApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onOpenURL { url in
                    _ = GoogleAuthService.shared.handleURL(url)
                    _ = WeChatAuthService.shared.handleOpenURL(url)
                    _ = AlipayAuthService.shared.handleOpenURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    _ = WeChatAuthService.shared.handleUniversalLink(activity)
                }
        }
    }
}

/// 未登录时展示登录页，登录后进入主界面
private struct RootView: View {
    @AppStorage(UserSession.isLoggedInKey) private var isLoggedIn = false
    @AppStorage(AppSettings.hasCompletedSplashKey) private var hasCompletedSplash = false
    @AppStorage(AppSettings.appearanceKey) private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage(AppSettings.skinKey) private var skinRaw = AppSkin.default.rawValue
    @StateObject private var galleryStore = GalleryStore.shared
    @StateObject private var engagementStore = ImageEngagementStore.shared
    @StateObject private var followStore = FollowStore.shared
    @StateObject private var tagStore = ImageTagStore.shared
    @StateObject private var homeAdStore = HomeAdStore.shared
    @StateObject private var activityStore = ActivityStore.shared

    private var preferredColorScheme: ColorScheme? {
        AppAppearance(rawValue: appearanceRaw)?.colorScheme
    }

    private var appSkin: AppSkin {
        AppSkin(rawValue: skinRaw) ?? .default
    }

    var body: some View {
        Group {
            if !hasCompletedSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        hasCompletedSplash = true
                    }
                }
            } else {
                // if isLoggedIn {
                    ContentView()
                        .environmentObject(galleryStore)
                        .environmentObject(engagementStore)
                        .environmentObject(followStore)
                        .environmentObject(tagStore)
                        .environmentObject(homeAdStore)
                        .environmentObject(activityStore)
                // } else {
                //     LoginView(isLoggedIn: $isLoggedIn)
                // }
            }
        }
        .environmentObject(activityStore)
        .applyAppSkin(appSkin)
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            GoogleAuthService.shared.configure()
            WeChatAuthService.shared.configure()
            AlipayAuthService.shared.configure()
            GoogleAuthService.shared.restorePreviousSignIn { restored in
                if restored {
                    isLoggedIn = true
                }
            }
            AppleAuthService.shared.restorePreviousSignIn { restored in
                if restored {
                    isLoggedIn = true
                }
            }
        }
    }
}
