//
//  PhoneCountryCode.swift
//  b-app-search
//

import SwiftUI

struct PhoneCountryCode: Identifiable, Hashable {
  let id: String
  let name: String
  let dialCode: String
  let flag: String
  let minLength: Int
  let maxLength: Int
  let requiredPrefix: String?

  var displayDialCode: String { "+\(dialCode)" }

  var lengthHint: String {
    if minLength == maxLength {
      return "\(minLength) 位"
    }
    return "\(minLength)-\(maxLength) 位"
  }

  var placeholder: String {
    "请输入 \(lengthHint)手机号"
  }

  func digits(from input: String) -> String {
    input.filter(\.isNumber)
  }

  func isValid(nationalNumber: String) -> Bool {
    validationMessage(for: nationalNumber) == nil
  }

  /// 返回 nil 表示校验通过；空输入不报错（由发送时再提示）
  func validationMessage(for nationalNumber: String) -> String? {
    let digits = digits(from: nationalNumber)
    guard !digits.isEmpty else { return nil }

    if digits.count < minLength {
      return "手机号位数不足，\(name) 需输入 \(lengthHint) 数字"
    }
    if digits.count > maxLength {
      return "手机号位数过多，\(name) 为 \(lengthHint) 数字"
    }
    if let requiredPrefix, !digits.hasPrefix(requiredPrefix) {
      return "请输入以 \(requiredPrefix) 开头的有效\(name)手机号"
    }
    return nil
  }

  func e164(from nationalNumber: String) -> String {
    "+\(dialCode)\(digits(from: nationalNumber))"
  }

  static let china = PhoneCountryCode(
    id: "CN",
    name: "中国大陆",
    dialCode: "86",
    flag: "🇨🇳",
    minLength: 11,
    maxLength: 11,
    requiredPrefix: "1"
  )

  /// 主流国家/地区，不含非洲等暂未开放注册的区域
  static let supported: [PhoneCountryCode] = [
    china,
    .init(id: "HK", name: "中国香港", dialCode: "852", flag: "🇭🇰", minLength: 8, maxLength: 8, requiredPrefix: nil),
    .init(id: "MO", name: "中国澳门", dialCode: "853", flag: "🇲🇴", minLength: 8, maxLength: 8, requiredPrefix: nil),
    .init(id: "TW", name: "中国台湾", dialCode: "886", flag: "🇹🇼", minLength: 9, maxLength: 9, requiredPrefix: "9"),
    .init(id: "US", name: "美国 / 加拿大", dialCode: "1", flag: "🇺🇸", minLength: 10, maxLength: 10, requiredPrefix: nil),
    .init(id: "JP", name: "日本", dialCode: "81", flag: "🇯🇵", minLength: 10, maxLength: 11, requiredPrefix: nil),
    .init(id: "KR", name: "韩国", dialCode: "82", flag: "🇰🇷", minLength: 10, maxLength: 11, requiredPrefix: nil),
    .init(id: "SG", name: "新加坡", dialCode: "65", flag: "🇸🇬", minLength: 8, maxLength: 8, requiredPrefix: nil),
    .init(id: "MY", name: "马来西亚", dialCode: "60", flag: "🇲🇾", minLength: 9, maxLength: 10, requiredPrefix: nil),
    .init(id: "TH", name: "泰国", dialCode: "66", flag: "🇹🇭", minLength: 9, maxLength: 9, requiredPrefix: nil),
    .init(id: "VN", name: "越南", dialCode: "84", flag: "🇻🇳", minLength: 9, maxLength: 10, requiredPrefix: nil),
    .init(id: "PH", name: "菲律宾", dialCode: "63", flag: "🇵🇭", minLength: 10, maxLength: 10, requiredPrefix: nil),
    .init(id: "ID", name: "印度尼西亚", dialCode: "62", flag: "🇮🇩", minLength: 9, maxLength: 12, requiredPrefix: nil),
    .init(id: "IN", name: "印度", dialCode: "91", flag: "🇮🇳", minLength: 10, maxLength: 10, requiredPrefix: nil),
    .init(id: "AU", name: "澳大利亚", dialCode: "61", flag: "🇦🇺", minLength: 9, maxLength: 9, requiredPrefix: nil),
    .init(id: "NZ", name: "新西兰", dialCode: "64", flag: "🇳🇿", minLength: 8, maxLength: 10, requiredPrefix: nil),
    .init(id: "GB", name: "英国", dialCode: "44", flag: "🇬🇧", minLength: 10, maxLength: 10, requiredPrefix: nil),
    .init(id: "DE", name: "德国", dialCode: "49", flag: "🇩🇪", minLength: 10, maxLength: 11, requiredPrefix: nil),
    .init(id: "FR", name: "法国", dialCode: "33", flag: "🇫🇷", minLength: 9, maxLength: 9, requiredPrefix: nil),
    .init(id: "IT", name: "意大利", dialCode: "39", flag: "🇮🇹", minLength: 9, maxLength: 10, requiredPrefix: nil),
    .init(id: "ES", name: "西班牙", dialCode: "34", flag: "🇪🇸", minLength: 9, maxLength: 9, requiredPrefix: nil),
    .init(id: "NL", name: "荷兰", dialCode: "31", flag: "🇳🇱", minLength: 9, maxLength: 9, requiredPrefix: nil),
    .init(id: "BE", name: "比利时", dialCode: "32", flag: "🇧🇪", minLength: 9, maxLength: 9, requiredPrefix: nil),
    .init(id: "CH", name: "瑞士", dialCode: "41", flag: "🇨🇭", minLength: 9, maxLength: 9, requiredPrefix: nil),
    .init(id: "AT", name: "奥地利", dialCode: "43", flag: "🇦🇹", minLength: 10, maxLength: 11, requiredPrefix: nil),
    .init(id: "SE", name: "瑞典", dialCode: "46", flag: "🇸🇪", minLength: 9, maxLength: 9, requiredPrefix: nil),
    .init(id: "NO", name: "挪威", dialCode: "47", flag: "🇳🇴", minLength: 8, maxLength: 8, requiredPrefix: nil),
    .init(id: "DK", name: "丹麦", dialCode: "45", flag: "🇩🇰", minLength: 8, maxLength: 8, requiredPrefix: nil),
    .init(id: "FI", name: "芬兰", dialCode: "358", flag: "🇫🇮", minLength: 9, maxLength: 10, requiredPrefix: nil),
    .init(id: "IE", name: "爱尔兰", dialCode: "353", flag: "🇮🇪", minLength: 9, maxLength: 9, requiredPrefix: nil),
    .init(id: "PT", name: "葡萄牙", dialCode: "351", flag: "🇵🇹", minLength: 9, maxLength: 9, requiredPrefix: nil),
    .init(id: "PL", name: "波兰", dialCode: "48", flag: "🇵🇱", minLength: 9, maxLength: 9, requiredPrefix: nil),
    .init(id: "RU", name: "俄罗斯", dialCode: "7", flag: "🇷🇺", minLength: 10, maxLength: 10, requiredPrefix: nil),
    .init(id: "TR", name: "土耳其", dialCode: "90", flag: "🇹🇷", minLength: 10, maxLength: 10, requiredPrefix: nil),
    .init(id: "AE", name: "阿联酋", dialCode: "971", flag: "🇦🇪", minLength: 9, maxLength: 9, requiredPrefix: nil),
    .init(id: "SA", name: "沙特阿拉伯", dialCode: "966", flag: "🇸🇦", minLength: 9, maxLength: 9, requiredPrefix: nil),
    .init(id: "IL", name: "以色列", dialCode: "972", flag: "🇮🇱", minLength: 9, maxLength: 9, requiredPrefix: nil),
    .init(id: "MX", name: "墨西哥", dialCode: "52", flag: "🇲🇽", minLength: 10, maxLength: 10, requiredPrefix: nil),
    .init(id: "BR", name: "巴西", dialCode: "55", flag: "🇧🇷", minLength: 10, maxLength: 11, requiredPrefix: nil),
    .init(id: "AR", name: "阿根廷", dialCode: "54", flag: "🇦🇷", minLength: 10, maxLength: 10, requiredPrefix: nil),
  ]

  static func find(dialCode: String) -> PhoneCountryCode? {
    supported.first { $0.dialCode == dialCode.filter(\.isNumber) }
  }
}

struct PhoneCountryCodePickerView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var selection: PhoneCountryCode
  @State private var query = ""

  private var filteredCountries: [PhoneCountryCode] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return PhoneCountryCode.supported }
    return PhoneCountryCode.supported.filter {
      $0.name.localizedCaseInsensitiveContains(trimmed)
        || $0.displayDialCode.contains(trimmed)
        || $0.dialCode.contains(trimmed.filter(\.isNumber))
    }
  }

  var body: some View {
    NavigationStack {
      List(filteredCountries) { country in
        Button {
          selection = country
          dismiss()
        } label: {
          HStack(spacing: 12) {
            Text(country.flag)
              .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
              Text(country.name)
                .foregroundStyle(.primary)
              Text(country.displayDialCode)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if country.id == selection.id {
              Image(systemName: "checkmark")
                .foregroundStyle(Color.accentColor)
            }
          }
        }
      }
      .listStyle(.plain)
      .searchable(text: $query, prompt: "搜索国家或区号")
      .navigationTitle("选择国家/地区")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("关闭") { dismiss() }
        }
      }
    }
  }
}
