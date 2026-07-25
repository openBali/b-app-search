//
//  PhoneLoginView.swift
//  b-app-search
//

import SwiftUI

@MainActor
final class PhoneLoginViewModel: ObservableObject {
  @Published var selectedCountry = PhoneCountryCode.china
  @Published var phoneNumber = ""
  @Published var verificationCode = ""
  @Published var countdownSeconds = 0
  @Published var codeSent = false
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var infoMessage: String?
  @Published var phoneValidationMessage: String?
  @Published var showCaptcha = false
  @Published var showCountryPicker = false

  private var countdownTask: Task<Void, Never>?

  deinit {
    countdownTask?.cancel()
  }

  var canSendCode: Bool {
    countdownSeconds == 0 && !isLoading
  }

  var canSubmit: Bool {
    selectedCountry.isValid(nationalNumber: phoneNumber)
      && verificationCode.count == 6
      && !isLoading
  }

  var sendCodeButtonTitle: String {
    if countdownSeconds > 0 {
      return "\(countdownSeconds)s 后重发"
    }
    return codeSent ? "重新获取" : "获取验证码"
  }

  private var normalizedPhone: String {
    selectedCountry.digits(from: phoneNumber)
  }

  private var e164Phone: String {
    selectedCountry.e164(from: phoneNumber)
  }

  func selectCountry(_ country: PhoneCountryCode) {
    selectedCountry = country
    sanitizePhoneNumber()
    refreshPhoneValidationMessage()
  }

  func sanitizePhoneNumber() {
    let filtered = String(selectedCountry.digits(from: phoneNumber).prefix(selectedCountry.maxLength))
    if filtered != phoneNumber {
      phoneNumber = filtered
    }
  }

  func refreshPhoneValidationMessage() {
    phoneValidationMessage = selectedCountry.validationMessage(for: phoneNumber)
  }

  func requestSendVerificationCode() {
    guard canSendCode else { return }

    errorMessage = nil
    infoMessage = nil

    let digits = normalizedPhone
    if digits.isEmpty {
      phoneValidationMessage = "请输入手机号"
      return
    }
    if let message = selectedCountry.validationMessage(for: digits) {
      phoneValidationMessage = message
      return
    }
    if !selectedCountry.isValid(nationalNumber: digits) {
      phoneValidationMessage = "请输入有效的\(selectedCountry.name)手机号"
      return
    }

    phoneValidationMessage = nil
    showCaptcha = true
  }

  func sendVerificationCodeAfterCaptcha() {
    guard canSendCode else { return }
    isLoading = true
    errorMessage = nil
    infoMessage = nil

    Task {
      do {
        try await BackendAPI.Auth.sendPhoneVerificationCode(
          countryCode: selectedCountry.dialCode,
          phone: normalizedPhone
        )
        codeSent = true
        infoMessage = "验证码已发送至 \(selectedCountry.displayDialCode) \(maskPhone(normalizedPhone))（演示环境任意 6 位数字均可）"
        startCountdown(from: 60)
      } catch {
        errorMessage = error.localizedDescription
      }
      isLoading = false
    }
  }

  func signIn(onSuccess: @escaping () -> Void) {
    let digits = normalizedPhone
    if digits.isEmpty {
      phoneValidationMessage = "请输入手机号"
      return
    }
    if let message = selectedCountry.validationMessage(for: digits) {
      phoneValidationMessage = message
      return
    }
    guard canSubmit else {
      if verificationCode.count != 6 {
        errorMessage = "请输入 6 位验证码"
      }
      return
    }

    isLoading = true
    errorMessage = nil

    Task {
      do {
        let session = try await BackendAPI.Auth.exchangePhoneVerification(
          countryCode: selectedCountry.dialCode,
          phone: normalizedPhone,
          code: verificationCode
        )
        BackendAPI.Auth.applySession(session, phone: e164Phone)
        onSuccess()
      } catch {
        errorMessage = error.localizedDescription
      }
      isLoading = false
    }
  }

  private func maskPhone(_ digits: String) -> String {
    guard digits.count >= 7 else { return digits }
    let prefix = digits.prefix(3)
    let suffix = digits.suffix(4)
    return "\(prefix)****\(suffix)"
  }

  private func startCountdown(from seconds: Int) {
    countdownTask?.cancel()
    countdownSeconds = seconds

    countdownTask = Task {
      while countdownSeconds > 0, !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        countdownSeconds -= 1
      }
      if !Task.isCancelled {
        countdownSeconds = 0
      }
    }
  }
}

struct PhoneLoginView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var viewModel = PhoneLoginViewModel()

  let onSuccess: () -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          header

          phoneField

          codeField

          if let info = viewModel.infoMessage {
            Text(info)
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          submitButton
        }
        .padding(24)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("手机号登录")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("关闭") { dismiss() }
        }
      }
      .overlay {
        if viewModel.isLoading {
          Color.black.opacity(0.12)
            .ignoresSafeArea()
          ProgressView()
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
      }
      .alert("提示", isPresented: errorBinding) {
        Button("确定", role: .cancel) {
          viewModel.errorMessage = nil
        }
      } message: {
        Text(viewModel.errorMessage ?? "")
      }
      .sheet(isPresented: $viewModel.showCountryPicker) {
        PhoneCountryCodePickerView(selection: $viewModel.selectedCountry)
      }
      .sheet(isPresented: $viewModel.showCaptcha) {
        SMSCaptchaChallengeView(
          onVerified: {
            viewModel.showCaptcha = false
            viewModel.sendVerificationCodeAfterCaptcha()
          },
          onCancel: {
            viewModel.showCaptcha = false
          }
        )
      }
      .onChange(of: viewModel.selectedCountry) { _ in
        viewModel.selectCountry(viewModel.selectedCountry)
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("手机号注册 / 登录")
        .font(.title3.weight(.semibold))

      Text("未注册的手机号验证后将自动创建账号。当前为演示模式，不会发送真实短信。")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }

  private var phoneField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("手机号")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      HStack(spacing: 10) {
        Button {
          viewModel.showCountryPicker = true
        } label: {
          HStack(spacing: 4) {
            Text(viewModel.selectedCountry.flag)
            Text(viewModel.selectedCountry.displayDialCode)
              .font(.body.weight(.medium))
            Image(systemName: "chevron.down")
              .font(.caption2.weight(.semibold))
          }
          .foregroundStyle(.primary)
          .padding(.horizontal, 10)
          .padding(.vertical, 12)
          .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)

        TextField(viewModel.selectedCountry.placeholder, text: $viewModel.phoneNumber)
          .keyboardType(.numberPad)
          .textContentType(.telephoneNumber)
          .padding(.horizontal, 12)
          .padding(.vertical, 12)
          .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          .onChange(of: viewModel.phoneNumber) { _ in
            viewModel.sanitizePhoneNumber()
            viewModel.refreshPhoneValidationMessage()
          }
      }

      if let validation = viewModel.phoneValidationMessage {
        Label(validation, systemImage: "exclamationmark.circle.fill")
          .font(.caption)
          .foregroundStyle(.red)
      } else if !viewModel.phoneNumber.isEmpty, viewModel.selectedCountry.isValid(nationalNumber: viewModel.phoneNumber) {
        Label("手机号格式正确", systemImage: "checkmark.circle.fill")
          .font(.caption)
          .foregroundStyle(.green)
      }
    }
  }

  private var codeField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("验证码")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      HStack(spacing: 10) {
        TextField("6 位验证码", text: $viewModel.verificationCode)
          .keyboardType(.numberPad)
          .textContentType(.oneTimeCode)
          .padding(.horizontal, 12)
          .padding(.vertical, 12)
          .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          .onChange(of: viewModel.verificationCode) { newValue in
            let filtered = String(newValue.filter(\.isNumber).prefix(6))
            if filtered != newValue {
              viewModel.verificationCode = filtered
            }
          }

        Button(viewModel.sendCodeButtonTitle) {
          viewModel.requestSendVerificationCode()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(viewModel.canSendCode ? Color.accentColor : Color.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .disabled(!viewModel.canSendCode)
      }
    }
  }

  private var submitButton: some View {
    Button {
      viewModel.signIn {
        onSuccess()
        dismiss()
      }
    } label: {
      Text("登录 / 注册")
        .font(.body.weight(.semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
    .buttonStyle(.borderedProminent)
    .disabled(!viewModel.canSubmit)
    .padding(.top, 8)
  }

  private var errorBinding: Binding<Bool> {
    Binding(
      get: { viewModel.errorMessage != nil },
      set: { if !$0 { viewModel.errorMessage = nil } }
    )
  }
}

struct PhoneLoginView_Previews: PreviewProvider {
  static var previews: some View {
    PhoneLoginView(onSuccess: {})
  }
}
