//
//  BackendAPI.swift
//  b-app-search
//
//  应用内所有后端 HTTP 接口的统一入口。
//  第三方 SDK（Google / 微信唤起）仍由 GoogleAuthService、WeChatAuthService 负责，
//  换取会话、业务数据读写均通过本文件。
//

import Foundation

// MARK: - Config

enum APIConfig {
  /// 后端根地址，上线前替换为真实域名。
  static let baseURL = URL(string: "https://api.example.com/v1")!

  /// `true`：走本地 Mock，不发起真实网络；`false`：使用 URLSession 请求 baseURL。
  static var useMockBackend = true

  static var defaultHeaders: [String: String] {
    var headers = [
      "Accept": "application/json",
      "Content-Type": "application/json"
    ]
    if let token = UserSession.accessToken, !token.isEmpty {
      headers["Authorization"] = "Bearer \(token)"
    }
    return headers
  }
}

// MARK: - Endpoint catalog

enum APIImplementationStatus: String {
  case mock = "Mock"
  case live = "HTTP"
  case sdk = "SDK+待对接"
  case local = "仅本地"
  case planned = "待实现"
}

struct APIEndpointInfo: Identifiable {
  let id: String
  let domain: String
  let method: String
  let path: String
  let status: APIImplementationStatus
  let summary: String
  /// 迁移前的实现位置，便于对照。
  let legacyNote: String?
}

extension BackendAPI {
  /// 项目内所有后端相关能力一览（含已对接 Mock、仅本地、规划中）。
  static let endpointCatalog: [APIEndpointInfo] = [
    // Auth
    .init(id: "auth.wechat", domain: "认证", method: "POST", path: "/auth/wechat",
          status: .mock, summary: "微信 code 换会话",
          legacyNote: "原 LoginViewModel.signInWithWeChat 内直接 UserSession.signIn"),
    .init(id: "auth.alipay.authInfo", domain: "认证", method: "POST", path: "/auth/alipay/auth-info",
          status: .mock, summary: "下发支付宝 auth_v2 签名串",
          legacyNote: "AlipayAuthService；私钥签名必须在服务端完成"),
    .init(id: "auth.alipay", domain: "认证", method: "POST", path: "/auth/alipay",
          status: .mock, summary: "支付宝 auth_code 换会话",
          legacyNote: "AlipayAuthService + LoginViewModel"),
    .init(id: "auth.google", domain: "认证", method: "POST", path: "/auth/google",
          status: .mock, summary: "Google id_token 换会话",
          legacyNote: "原 LoginViewModel.signInWithGoogle 模拟；GoogleAuthService 负责 SDK"),
    .init(id: "auth.apple", domain: "认证", method: "POST", path: "/auth/apple",
          status: .mock, summary: "Apple identityToken 换会话", legacyNote: "AppleAuthService + LoginViewModel"),
    .init(id: "auth.register", domain: "认证", method: "POST", path: "/auth/register",
          status: .planned, summary: "邮箱/手机号注册", legacyNote: "已由手机号验证码登录合并"),
    .init(id: "auth.phone.sendCode", domain: "认证", method: "POST", path: "/auth/phone/send-code",
          status: .mock, summary: "发送手机验证码", legacyNote: "PhoneLoginView 演示 UI"),
    .init(id: "auth.phone.verify", domain: "认证", method: "POST", path: "/auth/phone/verify",
          status: .mock, summary: "手机号验证码登录/注册", legacyNote: "PhoneLoginView"),
    .init(id: "auth.logout", domain: "认证", method: "POST", path: "/auth/logout",
          status: .planned, summary: "注销服务端会话", legacyNote: "UserSession.signOut 仅本地"),
    // User
    .init(id: "user.profile", domain: "用户", method: "PUT", path: "/users/me",
          status: .mock, summary: "更新昵称/简介/邮箱",
          legacyNote: "原 UserProfileView.saveProfile 仅 UserDefaults"),
    .init(id: "user.password", domain: "用户", method: "PUT", path: "/users/me/password",
          status: .mock, summary: "修改密码", legacyNote: "原 UserProfileView.changePassword 演示"),
    .init(id: "user.avatar", domain: "用户", method: "POST", path: "/users/me/avatar",
          status: .mock, summary: "上传头像",
          legacyNote: "原 UserSession.saveAvatar 仅本地文件"),
    // Gallery
    .init(id: "gallery.batchUpload", domain: "图库", method: "POST", path: "/gallery/images/batch-upload",
          status: .mock, summary: "批量同步图片到云端",
          legacyNote: "原 GalleryCloudSyncService.uploadImages"),
    .init(id: "gallery.publish", domain: "图库", method: "POST", path: "/gallery/images/publish",
          status: .planned, summary: "发布图片到公共 feed", legacyNote: "GalleryStore.publishImages 本地"),
    .init(id: "gallery.publicFeed", domain: "图库", method: "GET", path: "/gallery/images/public",
          status: .planned, summary: "拉取公共图片列表", legacyNote: "GalleryStore.publicImages 本地+样例"),
    .init(id: "gallery.tags", domain: "图库", method: "GET", path: "/gallery/tags",
          status: .mock, summary: "拉取图片标签列表", legacyNote: "ImageTagStore.fetchRemoteTags"),
    .init(id: "user.imageTags", domain: "用户", method: "PUT", path: "/users/me/image-tags",
          status: .mock, summary: "保存用户自定义标签", legacyNote: "ImageTagSettingsView 保存"),
    // Engagement
    .init(id: "engagement.like", domain: "互动", method: "POST", path: "/engagement/images/{key}/like",
          status: .local, summary: "点赞", legacyNote: "ImageEngagementStore + UserDefaults"),
    .init(id: "engagement.favorite", domain: "互动", method: "POST", path: "/engagement/images/{key}/favorite",
          status: .local, summary: "收藏", legacyNote: "ImageEngagementStore"),
    .init(id: "engagement.comments", domain: "互动", method: "GET", path: "/engagement/images/{key}/comments",
          status: .local, summary: "评论列表", legacyNote: "ImageEngagementStore"),
    .init(id: "engagement.commentPost", domain: "互动", method: "POST", path: "/engagement/images/{key}/comments",
          status: .local, summary: "发表评论", legacyNote: "ImageCommentsChatView → ImageEngagementStore"),
    // Search
    .init(id: "search.text", domain: "搜索", method: "GET", path: "/search/text",
          status: .local, summary: "关键词搜索图片", legacyNote: "HomeSearchService.searchText 本地过滤"),
    .init(id: "search.image", domain: "搜索", method: "POST", path: "/search/image",
          status: .mock, summary: "以图搜图", legacyNote: "HomeSearchService.searchByImage 随机样例"),
    // Home ads
    .init(id: "home.adPlacements", domain: "首页", method: "GET", path: "/home/ad-placements",
          status: .mock, summary: "首页广告推荐位列表", legacyNote: "HomeAdStore.fetchPlacements")
  ]
}

// MARK: - Errors

enum BackendAPIError: LocalizedError {
  case emptySelection
  case invalidURL
  case httpStatus(Int, String?)
  case decodingFailed
  case uploadFailed(String)
  case notConfigured(String)
  case cancelled

  var errorDescription: String? {
    switch self {
    case .emptySelection:
      return "请先选择要处理的图片"
    case .invalidURL:
      return "接口地址无效"
    case .httpStatus(let code, let message):
      return message ?? "请求失败（\(code)）"
    case .decodingFailed:
      return "服务器返回数据无法解析"
    case .uploadFailed(let message):
      return message
    case .notConfigured(let provider):
      return "请配置 \(provider)"
    case .cancelled:
      return "已取消"
    }
  }
}

/// 兼容旧调用方
typealias GalleryCloudSyncError = BackendAPIError

// MARK: - HTTP client

enum APIHTTPMethod: String {
  case get = "GET"
  case post = "POST"
  case put = "PUT"
  case delete = "DELETE"
}

private enum APIClient {
  static let session: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30
    return URLSession(configuration: config)
  }()

  static func request<Response: Decodable>(
    _ method: APIHTTPMethod,
    path: String,
    query: [String: String] = [:],
    body: Encodable? = nil
  ) async throws -> Response {
    if APIConfig.useMockBackend {
      throw BackendAPIError.uploadFailed("Mock 模式未实现该接口的泛型响应：\(path)")
    }

    guard var components = URLComponents(
      url: APIConfig.baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
      resolvingAgainstBaseURL: false
    ) else {
      throw BackendAPIError.invalidURL
    }
    if !query.isEmpty {
      components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
    guard let url = components.url else { throw BackendAPIError.invalidURL }

    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    APIConfig.defaultHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
    if let body {
      request.httpBody = try JSONEncoder.api.encode(AnyEncodable(body))
    }

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw BackendAPIError.uploadFailed("无有效 HTTP 响应")
    }
    guard (200..<300).contains(http.statusCode) else {
      let message = String(data: data, encoding: .utf8)
      throw BackendAPIError.httpStatus(http.statusCode, message)
    }
    do {
      return try JSONDecoder.api.decode(Response.self, from: data)
    } catch {
      throw BackendAPIError.decodingFailed
    }
  }

  static func requestVoid(
    _ method: APIHTTPMethod,
    path: String,
    body: Encodable? = nil
  ) async throws {
    if APIConfig.useMockBackend {
      try await Task.sleep(nanoseconds: 300_000_000)
      return
    }
    let _: EmptyResponse = try await request(method, path: path, body: body)
  }
}

private struct EmptyResponse: Decodable {}
private struct AnyEncodable: Encodable {
  let value: Encodable
  init(_ value: Encodable) { self.value = value }
  func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}

private extension JSONEncoder {
  static let api: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()
}

private extension JSONDecoder {
  static let api: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()
}

// MARK: - BackendAPI

enum BackendAPI {

  // MARK: Auth

  enum Auth {
    struct SessionResponse: Codable {
      let accessToken: String
      let nickname: String
      let email: String?
      let expiresAt: Date?
    }

    /// 微信授权 code → 服务端会话（原 LoginViewModel 内 TODO）
    static func exchangeWeChatCode(_ code: String) async throws -> SessionResponse {
      if APIConfig.useMockBackend {
        try await Task.sleep(nanoseconds: 500_000_000)
        return SessionResponse(
          accessToken: "mock-wechat-\(code.prefix(8))",
          nickname: "微信用户",
          email: nil,
          expiresAt: nil
        )
      }
      struct Body: Encodable { let code: String }
      let response: SessionResponse = try await APIClient.request(
        .post, path: "/auth/wechat", body: Body(code: code)
      )
      return response
    }

    /// 服务端生成支付宝 auth_v2 签名串（私钥不可下发到客户端）
    static func fetchAlipayAuthInfo() async throws -> String {
      if APIConfig.useMockBackend {
        try await Task.sleep(nanoseconds: 200_000_000)
        // Mock 仅用于演示；真机唤起支付宝需要服务端真实签名串
        return "mock-alipay-auth-info"
      }
      struct Body: Encodable {
        let appId: String
        let scheme: String
      }
      struct Response: Decodable {
        let authInfo: String
      }
      let response: Response = try await APIClient.request(
        .post,
        path: "/auth/alipay/auth-info",
        body: Body(appId: AuthConfig.alipayAppID, scheme: AuthConfig.alipayURLScheme)
      )
      return response.authInfo
    }

    /// 支付宝授权 auth_code → 服务端会话
    static func exchangeAlipayAuthCode(_ authCode: String) async throws -> SessionResponse {
      if APIConfig.useMockBackend {
        try await Task.sleep(nanoseconds: 500_000_000)
        return SessionResponse(
          accessToken: "mock-alipay-\(authCode.prefix(8))",
          nickname: "支付宝用户",
          email: nil,
          expiresAt: nil
        )
      }
      struct Body: Encodable {
        let authCode: String
        let appId: String
      }
      return try await APIClient.request(
        .post,
        path: "/auth/alipay",
        body: Body(authCode: authCode, appId: AuthConfig.alipayAppID)
      )
    }

    /// Google SDK 登录成功后，将 idToken 交给后端（真实环境）
    static func exchangeGoogleIDToken(_ idToken: String) async throws -> SessionResponse {
      if APIConfig.useMockBackend {
        try await Task.sleep(nanoseconds: 500_000_000)
        return SessionResponse(
          accessToken: "mock-google-token",
          nickname: "Google 用户",
          email: "user@gmail.com",
          expiresAt: nil
        )
      }
      struct Body: Encodable { let idToken: String }
      return try await APIClient.request(.post, path: "/auth/google", body: Body(idToken: idToken))
    }

    /// Apple 登录成功后，将 identityToken 交给后端（真实环境）
    static func exchangeAppleIdentityToken(
      _ identityToken: String,
      userIdentifier: String,
      email: String?,
      fullName: String?,
      authorizationCode: String?
    ) async throws -> SessionResponse {
      if APIConfig.useMockBackend {
        try await Task.sleep(nanoseconds: 500_000_000)
        let nickname = fullName ?? email?.components(separatedBy: "@").first ?? "Apple 用户"
        return SessionResponse(
          accessToken: "mock-apple-token",
          nickname: nickname,
          email: email,
          expiresAt: nil
        )
      }
      struct Body: Encodable {
        let identityToken: String
        let userIdentifier: String
        let email: String?
        let fullName: String?
        let authorizationCode: String?
      }
      return try await APIClient.request(
        .post,
        path: "/auth/apple",
        body: Body(
          identityToken: identityToken,
          userIdentifier: userIdentifier,
          email: email,
          fullName: fullName,
          authorizationCode: authorizationCode
        )
      )
    }

    static func applySession(
      _ session: SessionResponse,
      appleUserID: String? = nil,
      phone: String? = nil
    ) {
      UserSession.signIn(
        nickname: session.nickname,
        email: session.email,
        appleUserID: appleUserID,
        phone: phone
      )
      UserSession.saveAccessToken(session.accessToken)
    }

    /// 发送手机验证码（演示模式不真正发短信）
    static func sendPhoneVerificationCode(countryCode: String, phone: String) async throws {
      guard let country = PhoneCountryCode.find(dialCode: countryCode) else {
        throw BackendAPIError.uploadFailed("不支持的国家/地区区号")
      }

      let normalized = country.digits(from: phone)
      if let message = country.validationMessage(for: normalized) {
        throw BackendAPIError.uploadFailed(message)
      }
      guard country.isValid(nationalNumber: normalized) else {
        throw BackendAPIError.uploadFailed("请输入有效的手机号")
      }

      if APIConfig.useMockBackend {
        try await Task.sleep(nanoseconds: 450_000_000)
        return
      }

      struct Body: Encodable {
        let countryCode: String
        let phone: String
      }
      try await APIClient.requestVoid(
        .post,
        path: "/auth/phone/send-code",
        body: Body(countryCode: country.dialCode, phone: normalized)
      )
    }

    /// 手机号 + 验证码登录（未注册则自动注册）
    static func exchangePhoneVerification(
      countryCode: String,
      phone: String,
      code: String
    ) async throws -> SessionResponse {
      guard let country = PhoneCountryCode.find(dialCode: countryCode) else {
        throw BackendAPIError.uploadFailed("不支持的国家/地区区号")
      }

      let normalizedPhone = country.digits(from: phone)
      let normalizedCode = code.filter(\.isNumber)

      if let message = country.validationMessage(for: normalizedPhone) {
        throw BackendAPIError.uploadFailed(message)
      }
      guard country.isValid(nationalNumber: normalizedPhone) else {
        throw BackendAPIError.uploadFailed("请输入有效的手机号")
      }
      guard normalizedCode.count == 6 else {
        throw BackendAPIError.uploadFailed("请输入 6 位验证码")
      }

      if APIConfig.useMockBackend {
        try await Task.sleep(nanoseconds: 500_000_000)
        return SessionResponse(
          accessToken: "mock-phone-\(normalizedPhone.suffix(4))",
          nickname: "用户\(normalizedPhone.suffix(4))",
          email: nil,
          expiresAt: nil
        )
      }

      struct Body: Encodable {
        let countryCode: String
        let phone: String
        let code: String
      }
      return try await APIClient.request(
        .post,
        path: "/auth/phone/verify",
        body: Body(countryCode: country.dialCode, phone: normalizedPhone, code: normalizedCode)
      )
    }
  }

  // MARK: User

  enum User {
    struct ProfilePayload: Encodable {
      let nickname: String
      let bio: String
      let email: String
    }

    struct ProfileResponse: Codable {
      let nickname: String
      let bio: String
      let email: String
    }

    static func updateProfile(nickname: String, bio: String, email: String) async throws -> ProfileResponse {
      let payload = ProfilePayload(nickname: nickname, bio: bio, email: email)
      if APIConfig.useMockBackend {
        try await Task.sleep(nanoseconds: 350_000_000)
        return ProfileResponse(nickname: nickname, bio: bio, email: email)
      }
      return try await APIClient.request(.put, path: "/users/me", body: payload)
    }

    static func changePassword(current: String, newPassword: String) async throws {
      if APIConfig.useMockBackend {
        try await Task.sleep(nanoseconds: 350_000_000)
        guard !current.isEmpty, newPassword.count >= 6 else {
          throw BackendAPIError.uploadFailed("密码不符合要求")
        }
        return
      }
      struct Body: Encodable {
        let currentPassword: String
        let newPassword: String
      }
      try await APIClient.requestVoid(.put, path: "/users/me/password", body: Body(currentPassword: current, newPassword: newPassword))
    }

    static func uploadAvatar(_ imageData: Data) async throws -> URL {
      if APIConfig.useMockBackend {
        try await Task.sleep(nanoseconds: 400_000_000)
        try UserSession.saveAvatar(imageData)
        return UserSession.avatarURL ?? URL(fileURLWithPath: "/")
      }
      // 真实环境可改为 multipart/form-data
      struct Body: Encodable { let imageBase64: String }
      struct Response: Decodable { let avatarURL: URL }
      let response: Response = try await APIClient.request(
        .post,
        path: "/users/me/avatar",
        body: Body(imageBase64: imageData.base64EncodedString())
      )
      return response.avatarURL
    }
  }

  // MARK: Gallery

  enum Gallery {
    struct UploadPayload: Encodable {
      let imageId: Int
      let engagementKey: String
      let title: String
      let tag: String
      let description: String
      let latitude: Double
      let longitude: Double
      let locationName: String?
      let category: String
      let mediaType: String
      let mediaURL: String?
      let isPublished: Bool
      let fileSize: Int
    }

    struct UploadResponse: Codable {
      let cloudId: String
      let imageId: Int
      let syncedAt: Date
    }

    /// 批量上传 / 同步（原 GalleryCloudSyncService.uploadImages）
    static func batchUpload(_ images: [GalleryImage]) async throws -> [UploadResponse] {
      guard !images.isEmpty else { throw BackendAPIError.emptySelection }

      var payloads: [UploadPayload] = []
      for image in images {
        let fileSize: Int
        if image.url.isFileURL, let data = try? Data(contentsOf: image.url) {
          fileSize = data.count
        } else {
          fileSize = 0
        }
        payloads.append(
          UploadPayload(
            imageId: image.id,
            engagementKey: image.engagementKey,
            title: image.title,
            tag: image.tag,
            description: image.description,
            latitude: image.latitude,
            longitude: image.longitude,
            locationName: image.locationName,
            category: image.category.rawValue,
            mediaType: image.mediaType.rawValue,
            mediaURL: image.mediaURL?.absoluteString,
            isPublished: image.isPublished,
            fileSize: fileSize
          )
        )
      }

      if APIConfig.useMockBackend {
        try await Task.sleep(nanoseconds: 900_000_000)
        _ = try JSONEncoder.api.encode(["images": payloads])
        return images.map { image in
          UploadResponse(
            cloudId: "cloud-\(image.id)-\(UUID().uuidString.prefix(8))",
            imageId: image.id,
            syncedAt: Date()
          )
        }
      }

      struct Body: Encodable { let images: [UploadPayload] }
      struct Response: Decodable { let results: [UploadResponse] }
      let response: Response = try await APIClient.request(
        .post, path: "/gallery/images/batch-upload", body: Body(images: payloads)
      )
      return response.results
    }

    static func publish(imageIds: [Int]) async throws {
      if APIConfig.useMockBackend {
        try await Task.sleep(nanoseconds: 300_000_000)
        return
      }
      struct Body: Encodable { let imageIds: [Int] }
      try await APIClient.requestVoid(.post, path: "/gallery/images/publish", body: Body(imageIds: imageIds))
    }

    static func fetchPublicFeed() async throws -> [GalleryImage] {
      if APIConfig.useMockBackend {
        return GalleryImage.samples
      }
      throw BackendAPIError.uploadFailed("远程公共 feed 模型待与后端对齐后实现")
    }
  }

  // MARK: Tags

  enum Tags {
    struct TagItem: Codable {
      let name: String
      let sortOrder: Int?
    }

    struct ListResponse: Codable {
      let tags: [TagItem]
    }

    struct SaveUserTagsPayload: Encodable {
      let tags: [String]
    }

    /// 拉取服务端下发的图片标签（与本地合并展示）
    static func fetchImageTags() async throws -> [String] {
      if APIConfig.useMockBackend {
        try await Task.sleep(nanoseconds: 450_000_000)
        return ["夜景", "美食", "旅行", "人文", "海景"]
      }

      let response: ListResponse = try await APIClient.request(.get, path: "/gallery/tags")
      return response.tags
        .sorted { ($0.sortOrder ?? Int.max) < ($1.sortOrder ?? Int.max) }
        .map(\.name)
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// 将用户自定义标签同步到服务端
    static func saveUserTags(_ tags: [String]) async throws {
      let payload = SaveUserTagsPayload(tags: tags)
      if APIConfig.useMockBackend {
        try await Task.sleep(nanoseconds: 350_000_000)
        return
      }
      try await APIClient.requestVoid(.put, path: "/users/me/image-tags", body: payload)
    }
  }

  // MARK: Home Ads

  enum HomeAds {
    struct PlacementDTO: Codable {
      let id: String
      let sortOrder: Int?
      let heroImageURL: String
      let brandLogoURL: String?
      let brandName: String
      let brandIntro: String
      let hotProductCopy: String
      let landingURL: String?
    }

    struct ListResponse: Codable {
      let placements: [PlacementDTO]
    }

    /// 拉取首页广告推荐位（搜索条下方横向推荐层）
    static func fetchPlacements() async throws -> [HomeAdPlacement] {
      if APIConfig.useMockBackend {
        try await Task.sleep(nanoseconds: 320_000_000)
        return HomeAdPlacement.mockPlacements
      }

      let response: ListResponse = try await APIClient.request(.get, path: "/home/ad-placements")
      return response.placements
        .sorted { ($0.sortOrder ?? Int.max) < ($1.sortOrder ?? Int.max) }
        .compactMap(mapPlacement(from:))
    }

    private static func mapPlacement(from dto: PlacementDTO) -> HomeAdPlacement? {
      let trimmedName = dto.brandName.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedName.isEmpty else { return nil }
      guard let heroURL = URL(string: dto.heroImageURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        return nil
      }

      return HomeAdPlacement(
        id: dto.id,
        sortOrder: dto.sortOrder ?? Int.max,
        heroImageURL: heroURL,
        brandLogoURL: dto.brandLogoURL.flatMap { URL(string: $0.trimmingCharacters(in: .whitespacesAndNewlines)) },
        brandName: trimmedName,
        brandIntro: dto.brandIntro.trimmingCharacters(in: .whitespacesAndNewlines),
        hotProductCopy: dto.hotProductCopy.trimmingCharacters(in: .whitespacesAndNewlines),
        landingURL: dto.landingURL.flatMap { URL(string: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
      )
    }
  }

  // MARK: Engagement（当前仍主要走 ImageEngagementStore 本地；此处为服务端接口占位）

  enum Engagement {
    struct CommentDTO: Codable {
      let id: UUID
      let engagementKey: String
      let author: String
      let content: String
      let createdAt: Date
    }

    static func fetchComments(engagementKey: String) async throws -> [CommentDTO] {
      if APIConfig.useMockBackend {
        return []
      }
      return try await APIClient.request(
        .get, path: "/engagement/images/\(engagementKey)/comments"
      )
    }

    static func postComment(engagementKey: String, author: String, content: String) async throws -> CommentDTO {
      if APIConfig.useMockBackend {
        return CommentDTO(
          id: UUID(),
          engagementKey: engagementKey,
          author: author,
          content: content,
          createdAt: Date()
        )
      }
      struct Body: Encodable { let author: String; let content: String }
      return try await APIClient.request(
        .post,
        path: "/engagement/images/\(engagementKey)/comments",
        body: Body(author: author, content: content)
      )
    }

    static func setLiked(engagementKey: String, liked: Bool) async throws {
      if APIConfig.useMockBackend { return }
      struct Body: Encodable { let liked: Bool }
      try await APIClient.requestVoid(
        .post,
        path: "/engagement/images/\(engagementKey)/like",
        body: Body(liked: liked)
      )
    }
  }

  // MARK: Search

  enum Search {
    struct ImageSearchPayload: Encodable {
      let imageBase64: String
    }

    struct ImageSearchResponse: Decodable {
      let imageIds: [Int]
    }

    /// 服务端文本搜索；未接后端时由调用方回退到 HomeSearchService 本地过滤。
    static func searchText(_ query: String) async throws -> [Int] {
      if APIConfig.useMockBackend {
        return []
      }
      struct Response: Decodable { let imageIds: [Int] }
      let response: Response = try await APIClient.request(
        .get, path: "/search/text", query: ["q": query]
      )
      return response.imageIds
    }

    /// 以图搜图（原 HomeSearchService.searchByImage 的远程版）
    static func searchByImage(data: Data, candidateImages: [GalleryImage]) async throws -> [GalleryImage] {
      if APIConfig.useMockBackend {
        try await Task.sleep(nanoseconds: 500_000_000)
        return HomeSearchService.searchByImage(in: candidateImages)
      }
      struct Body: Encodable { let imageBase64: String }
      let response: ImageSearchResponse = try await APIClient.request(
        .post, path: "/search/image", body: Body(imageBase64: data.base64EncodedString())
      )
      let idSet = Set(response.imageIds)
      return candidateImages.filter { idSet.contains($0.id) }
    }
  }
}
