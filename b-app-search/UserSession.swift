//
//  UserSession.swift
//  b-app-search
//

import Foundation

enum UserSession {
  static let isLoggedInKey = "isLoggedIn"
  static let userNicknameKey = "userNickname"
  static let userBioKey = "userBio"
  static let userEmailKey = "userEmail"
  static let userPhoneKey = "userPhone"
  static let userAgeKey = "userAge"
  static let userAvatarFilenameKey = "userAvatarFilename"
  static let accessTokenKey = "accessToken"
  static let appleUserIDKey = "appleUserID"

  static var isLoggedIn: Bool {
    UserDefaults.standard.bool(forKey: isLoggedInKey)
  }

  static var nickname: String {
    UserDefaults.standard.string(forKey: userNicknameKey) ?? ""
  }

  static var bio: String {
    UserDefaults.standard.string(forKey: userBioKey) ?? ""
  }

  static var email: String {
    UserDefaults.standard.string(forKey: userEmailKey) ?? ""
  }

  static var phone: String {
    UserDefaults.standard.string(forKey: userPhoneKey) ?? ""
  }

  static var age: String {
    UserDefaults.standard.string(forKey: userAgeKey) ?? ""
  }

  static var accessToken: String? {
    UserDefaults.standard.string(forKey: accessTokenKey)
  }

  static func saveAccessToken(_ token: String) {
    UserDefaults.standard.set(token, forKey: accessTokenKey)
  }

  private static var avatarDirectory: URL {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documents.appendingPathComponent("UserAvatar", isDirectory: true)
  }

  static var avatarURL: URL? {
    guard
      let filename = UserDefaults.standard.string(forKey: userAvatarFilenameKey),
      !filename.isEmpty
    else { return nil }
    let url = avatarDirectory.appendingPathComponent(filename)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return url
  }

  static func signIn(
    nickname: String,
    email: String? = nil,
    appleUserID: String? = nil,
    phone: String? = nil
  ) {
    UserDefaults.standard.set(true, forKey: isLoggedInKey)
    UserDefaults.standard.set(nickname, forKey: userNicknameKey)
    if let email, !email.isEmpty {
      UserDefaults.standard.set(email, forKey: userEmailKey)
    }
    if let appleUserID, !appleUserID.isEmpty {
      UserDefaults.standard.set(appleUserID, forKey: appleUserIDKey)
    }
    if let phone, !phone.isEmpty {
      UserDefaults.standard.set(phone, forKey: userPhoneKey)
    }
  }

  static func updateProfile(nickname: String, bio: String, email: String) {
    UserDefaults.standard.set(nickname, forKey: userNicknameKey)
    UserDefaults.standard.set(bio, forKey: userBioKey)
    UserDefaults.standard.set(email, forKey: userEmailKey)
  }

  static func updateContact(phone: String, age: String) {
    UserDefaults.standard.set(phone, forKey: userPhoneKey)
    UserDefaults.standard.set(age, forKey: userAgeKey)
  }

  static func saveAvatar(_ data: Data) throws {
    try FileManager.default.createDirectory(at: avatarDirectory, withIntermediateDirectories: true)
    removeAvatarFileOnly()
    let filename = UUID().uuidString + ".jpg"
    let url = avatarDirectory.appendingPathComponent(filename)
    try data.write(to: url, options: .atomic)
    UserDefaults.standard.set(filename, forKey: userAvatarFilenameKey)
  }

  static func removeAvatar() {
    removeAvatarFileOnly()
    UserDefaults.standard.removeObject(forKey: userAvatarFilenameKey)
  }

  static func signOut() {
    UserDefaults.standard.set(false, forKey: isLoggedInKey)
    UserDefaults.standard.removeObject(forKey: userNicknameKey)
    UserDefaults.standard.removeObject(forKey: userBioKey)
    UserDefaults.standard.removeObject(forKey: userEmailKey)
    UserDefaults.standard.removeObject(forKey: userPhoneKey)
    UserDefaults.standard.removeObject(forKey: userAgeKey)
    UserDefaults.standard.removeObject(forKey: accessTokenKey)
    UserDefaults.standard.removeObject(forKey: appleUserIDKey)
    removeAvatar()
  }

  private static func removeAvatarFileOnly() {
    guard let url = avatarURL else { return }
    try? FileManager.default.removeItem(at: url)
  }
}
