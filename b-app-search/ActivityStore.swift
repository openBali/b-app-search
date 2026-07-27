//
//  ActivityStore.swift
//  b-app-search
//

import Foundation
import SwiftUI

@MainActor
final class ActivityStore: ObservableObject {
  static let shared = ActivityStore()

  @Published private(set) var campaigns: [ActivityCampaign] = []
  @Published private(set) var progressByCampaignId: [String: ActivityProgress] = [:]
  @Published private(set) var rewardGrants: [ActivityRewardGrant] = []
  @Published private(set) var isLoading = false
  @Published private(set) var lastErrorMessage: String?
  /// 最新一次发奖，供 UI 弹提示。
  @Published var latestRewardToast: ActivityRewardGrant?

  private let progressStorageKey = "activityStore.progress"
  private let rewardsStorageKey = "activityStore.rewards"
  private let campaignsCacheKey = "activityStore.campaigns"

  private init() {
    loadLocalState()
    Task { await fetchCampaigns() }
  }

  var activeCampaigns: [ActivityCampaign] {
    campaigns
      .filter(\.isActive)
      .sorted { $0.sortOrder < $1.sortOrder }
  }

  var primaryCampaign: ActivityCampaign? {
    activeCampaigns.first
  }

  func progress(for campaign: ActivityCampaign) -> ActivityProgress {
    progressByCampaignId[campaign.id]
      ?? ActivityProgress(campaignId: campaign.id)
  }

  func progressFraction(for campaign: ActivityCampaign) -> Double {
    let current = Double(progress(for: campaign).currentCount)
    let target = Double(max(campaign.targetCount, 1))
    return min(max(current / target, 0), 1)
  }

  func fetchCampaigns() async {
    guard !isLoading else { return }
    isLoading = true
    lastErrorMessage = nil
    defer { isLoading = false }

    do {
      let remote = try await BackendAPI.Activities.fetchActiveCampaigns()
      campaigns = remote.isEmpty ? ActivityCampaign.mockCampaigns : remote
      ensureProgressSlots()
      persistCampaignsCache()
    } catch {
      lastErrorMessage = error.localizedDescription
      if campaigns.isEmpty {
        campaigns = ActivityCampaign.mockCampaigns
        ensureProgressSlots()
      }
    }
  }

  /// 由互动事件驱动；按后端规则动态匹配活动。
  func record(_ event: ActivityEvent) {
    guard event.amount > 0 else { return }
    ensureProgressSlots()

    var progressMap = progressByCampaignId
    var grants = rewardGrants
    var toast: ActivityRewardGrant?

    for campaign in activeCampaigns where campaign.rule.trigger == event.trigger {
      var progress = progressMap[campaign.id] ?? ActivityProgress(campaignId: campaign.id)
      progress.currentCount += event.amount
      progress.updatedAt = Date()

      let target = campaign.targetCount
      while progress.currentCount >= target {
        progress.completedRounds += 1
        let grant = ActivityRewardGrant(
          campaignId: campaign.id,
          campaignTitle: campaign.title,
          rewardTitle: campaign.reward.title,
          rewardDetail: campaign.reward.detail,
          brandName: campaign.reward.brandName,
          roundIndex: progress.completedRounds
        )
        grants.insert(grant, at: 0)
        toast = grant

        if campaign.rule.autoRestart {
          progress.currentCount -= target
        } else {
          progress.currentCount = target
          break
        }
      }

      progressMap[campaign.id] = progress
    }

    progressByCampaignId = progressMap
    rewardGrants = grants
    if let toast {
      latestRewardToast = toast
    }
    persistLocalState()
  }

  func dismissRewardToast() {
    latestRewardToast = nil
  }

  func markRewardClaimed(_ id: UUID) {
    guard let index = rewardGrants.firstIndex(where: { $0.id == id }) else { return }
    rewardGrants[index].isClaimed = true
    persistLocalState()
  }

  private func ensureProgressSlots() {
    var map = progressByCampaignId
    for campaign in campaigns {
      if map[campaign.id] == nil {
        map[campaign.id] = ActivityProgress(campaignId: campaign.id)
      }
    }
    progressByCampaignId = map
  }

  private func loadLocalState() {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    if let data = UserDefaults.standard.data(forKey: campaignsCacheKey),
       let cached = try? decoder.decode([ActivityCampaign].self, from: data),
       !cached.isEmpty {
      campaigns = cached
    } else {
      campaigns = ActivityCampaign.mockCampaigns
    }

    if let data = UserDefaults.standard.data(forKey: progressStorageKey),
       let stored = try? decoder.decode([String: ActivityProgress].self, from: data) {
      progressByCampaignId = stored
    }

    if let data = UserDefaults.standard.data(forKey: rewardsStorageKey),
       let stored = try? decoder.decode([ActivityRewardGrant].self, from: data) {
      rewardGrants = stored
    }

    ensureProgressSlots()
  }

  private func persistLocalState() {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    if let progressData = try? encoder.encode(progressByCampaignId) {
      UserDefaults.standard.set(progressData, forKey: progressStorageKey)
    }
    if let rewardsData = try? encoder.encode(rewardGrants) {
      UserDefaults.standard.set(rewardsData, forKey: rewardsStorageKey)
    }
  }

  private func persistCampaignsCache() {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(campaigns) else { return }
    UserDefaults.standard.set(data, forKey: campaignsCacheKey)
  }
}
