//
//  ActivityModels.swift
//  b-app-search
//
//  运营活动：由后端下发配置，客户端按规则累计并自动发奖 / 重置。
//

import Foundation

/// 活动触发事件（后续可扩展分享、评论等）。
enum ActivityTriggerKind: String, Codable, CaseIterable, Hashable {
  case likeAdded
  case favoriteAdded
  case commentPosted
  case shareCompleted
}

/// 奖励类型；当前 mock 为「无消费券抵扣」的兑换礼。
enum ActivityRewardType: String, Codable, Hashable {
  /// 实物 / 门店兑换，无消费券抵扣。
  case giftNoCoupon
  case coupon
  case points
}

struct ActivityRule: Codable, Hashable {
  let trigger: ActivityTriggerKind
  let targetCount: Int
  /// 达标后是否清零进度并开始下一轮。
  let autoRestart: Bool

  init(trigger: ActivityTriggerKind, targetCount: Int, autoRestart: Bool = true) {
    self.trigger = trigger
    self.targetCount = max(targetCount, 1)
    self.autoRestart = autoRestart
  }
}

struct ActivityReward: Codable, Hashable {
  let type: ActivityRewardType
  let title: String
  let detail: String
  let brandName: String?

  init(
    type: ActivityRewardType,
    title: String,
    detail: String,
    brandName: String? = nil
  ) {
    self.type = type
    self.title = title
    self.detail = detail
    self.brandName = brandName
  }
}

/// 后端下发的活动定义；新增活动只需扩展字段 / trigger，不必改发奖主流程。
struct ActivityCampaign: Identifiable, Codable, Hashable {
  let id: String
  let title: String
  let subtitle: String
  let isActive: Bool
  let sortOrder: Int
  let rule: ActivityRule
  let reward: ActivityReward
  /// 预留扩展字段（后端动态参数）。
  let metadata: [String: String]?

  var targetCount: Int { rule.targetCount }
}

struct ActivityProgress: Codable, Hashable {
  var campaignId: String
  var currentCount: Int
  var completedRounds: Int
  var updatedAt: Date

  init(campaignId: String, currentCount: Int = 0, completedRounds: Int = 0, updatedAt: Date = Date()) {
    self.campaignId = campaignId
    self.currentCount = max(0, currentCount)
    self.completedRounds = max(0, completedRounds)
    self.updatedAt = updatedAt
  }

  func clamped(to target: Int) -> ActivityProgress {
    var copy = self
    copy.currentCount = min(max(0, currentCount), max(target, 1))
    return copy
  }
}

struct ActivityRewardGrant: Identifiable, Codable, Hashable {
  let id: UUID
  let campaignId: String
  let campaignTitle: String
  let rewardTitle: String
  let rewardDetail: String
  let brandName: String?
  let roundIndex: Int
  let grantedAt: Date
  var isClaimed: Bool

  init(
    id: UUID = UUID(),
    campaignId: String,
    campaignTitle: String,
    rewardTitle: String,
    rewardDetail: String,
    brandName: String?,
    roundIndex: Int,
    grantedAt: Date = Date(),
    isClaimed: Bool = false
  ) {
    self.id = id
    self.campaignId = campaignId
    self.campaignTitle = campaignTitle
    self.rewardTitle = rewardTitle
    self.rewardDetail = rewardDetail
    self.brandName = brandName
    self.roundIndex = roundIndex
    self.grantedAt = grantedAt
    self.isClaimed = isClaimed
  }
}

struct ActivityEvent {
  let trigger: ActivityTriggerKind
  let amount: Int

  static func likeAdded(amount: Int = 1) -> ActivityEvent {
    ActivityEvent(trigger: .likeAdded, amount: amount)
  }

  static func favoriteAdded(amount: Int = 1) -> ActivityEvent {
    ActivityEvent(trigger: .favoriteAdded, amount: amount)
  }

  static func commentPosted(amount: Int = 1) -> ActivityEvent {
    ActivityEvent(trigger: .commentPosted, amount: amount)
  }
}

extension ActivityCampaign {
  /// 客户端固定 mock：点赞满 100 送瑞幸一杯，无消费券抵扣，达标后重新累计。
  static let mockCampaigns: [ActivityCampaign] = [
    ActivityCampaign(
      id: "luckin-like-100",
      title: "点赞赢瑞幸",
      subtitle: "累计点赞 100 次，送瑞幸咖啡一杯（无消费券抵扣）；达标后自动重新计算。",
      isActive: true,
      sortOrder: 0,
      rule: ActivityRule(trigger: .likeAdded, targetCount: 100, autoRestart: true),
      reward: ActivityReward(
        type: .giftNoCoupon,
        title: "瑞幸咖啡一杯",
        detail: "无消费券抵扣",
        brandName: "瑞幸咖啡"
      ),
      metadata: [
        "partner": "luckin",
        "redeemHint": "到店出示兑换码"
      ]
    )
  ]
}
