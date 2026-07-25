//
//  LoginView.swift
//  b-app-search
//

import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LoginViewModel()
    @State private var showPhoneLogin = false

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 28) {
                    Spacer(minLength: 24)

                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 64, weight: .thin))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)

                        Text("欢迎回来")
                            .font(.title2.weight(.semibold))

                        Text("选择一种方式登录")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 8)

                    VStack(spacing: 14) {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                viewModel.handleAppleAuthorization(authorization) {
                                    isLoggedIn = true
                                    dismiss()
                                }
                            case .failure(let error):
                                viewModel.handleAppleSignInFailure(error)
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .disabled(viewModel.isLoading)

                        Button {
                            viewModel.signInWithWeChat {
                                isLoggedIn = true
                                dismiss()
                            }
                        } label: {
                            Label("微信登录", systemImage: "message.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(red: 0.09, green: 0.69, blue: 0.38))
                        )
                        .disabled(viewModel.isLoading)

                        Button {
                            viewModel.signInWithAlipay {
                                isLoggedIn = true
                                dismiss()
                            }
                        } label: {
                            Label("支付宝登录", systemImage: "yensign.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(red: 0.10, green: 0.45, blue: 0.91))
                        )
                        .disabled(viewModel.isLoading)

                        Button {
                            viewModel.signInWithGoogle {
                                isLoggedIn = true
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Text("G")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.26, green: 0.52, blue: 0.96),
                                                Color(red: 0.92, green: 0.25, blue: 0.21),
                                                Color(red: 0.98, green: 0.74, blue: 0.02),
                                                Color(red: 0.20, green: 0.66, blue: 0.33)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text("Google 登录")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color(.separator), lineWidth: 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                        )
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.horizontal, 24)

                    tipsRow

                    Spacer()
                    Spacer(minLength: 24)
                }

                if viewModel.isLoading {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    ProgressView("登录中…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .alert("登录失败", isPresented: errorBinding) {
                Button("确定", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showPhoneLogin) {
                PhoneLoginView {
                    isLoggedIn = true
                    dismiss()
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    /// 手机号注册 / 登录入口
    private var tipsRow: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 0.5)
                Text("或")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 0.5)
            }
            .padding(.horizontal, 24)

            Button {
                showPhoneLogin = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "iphone")
                    Text("手机号登录 / 注册")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(.separator), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
        }
        .padding(.top, 4)
    }
}

struct LoginView_Previews: PreviewProvider {
    struct Host: View {
        @State private var loggedIn = false
        var body: some View {
            LoginView(isLoggedIn: $loggedIn)
        }
    }

    static var previews: some View {
        Host()
    }
}
