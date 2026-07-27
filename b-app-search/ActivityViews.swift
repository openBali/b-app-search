//
//  ActivityViews.swift
//  b-app-search
//

import SwiftUI

/// 首页轻量活动进度条。
struct HomeActivityBanner: View {
  @EnvironmentObject private var activityStore: ActivityStore

  var body: some View {
    if let campaign = activityStore.primaryCampaign {
      let progress = activityStore.progress(for: campaign)
      NavigationLink {
        ActivityCenterView()
      } label: {
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 8) {
            Image(systemName: "gift.fill")
              .foregroundStyle(Color(red: 0.95, green: 0.35, blue: 0.32))
            Text(campaign.title)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Text("\(progress.currentCount)/\(campaign.targetCount)")
              .font(.caption.weight(.bold))
              .monospacedDigit()
              .foregroundStyle(.secondary)
          }

          ProgressView(value: activityStore.progressFraction(for: campaign))
            .tint(Color(red: 0.95, green: 0.35, blue: 0.32))

          Text(campaign.reward.title + " · " + campaign.reward.detail)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)
    }
  }
}

struct ActivityCenterView: View {
  @EnvironmentObject private var activityStore: ActivityStore

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        if activityStore.activeCampaigns.isEmpty {
          emptyCampaigns
        } else {
          ForEach(activityStore.activeCampaigns) { campaign in
            ActivityCampaignCard(campaign: campaign)
          }
        }

        rewardsSection
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .padding(.bottom, 28)
    }
    .background(Color(.systemGroupedBackground).ignoresSafeArea())
    .navigationTitle("活动")
    .navigationBarTitleDisplayMode(.inline)
    .refreshable {
      await activityStore.fetchCampaigns()
    }
    .task {
      await activityStore.fetchCampaigns()
    }
  }

  private var emptyCampaigns: some View {
    VStack(spacing: 10) {
      Image(systemName: "gift")
        .font(.title)
        .foregroundStyle(.secondary)
      Text("暂无进行中的活动")
        .font(.subheadline.weight(.semibold))
      Text("活动由后端下发后会显示在这里")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 36)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var rewardsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("我的奖励")
        .font(.headline)
        .padding(.horizontal, 4)

      if activityStore.rewardGrants.isEmpty {
        Text("达标后奖励会出现在这里")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(16)
          .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      } else {
        VStack(spacing: 10) {
          ForEach(activityStore.rewardGrants) { grant in
            ActivityRewardCard(grant: grant) {
              activityStore.markRewardClaimed(grant.id)
            }
          }
        }
      }
    }
  }
}

private struct ActivityCampaignCard: View {
  @EnvironmentObject private var activityStore: ActivityStore
  let campaign: ActivityCampaign

  private var progress: ActivityProgress {
    activityStore.progress(for: campaign)
  }

  private var remaining: Int {
    max(campaign.targetCount - progress.currentCount, 0)
  }

  private var accent: Color {
    Color(red: 0.95, green: 0.35, blue: 0.32)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "cup.and.saucer.fill")
          .font(.title3)
          .foregroundStyle(.white)
          .frame(width: 44, height: 44)
          .background(accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

        VStack(alignment: .leading, spacing: 4) {
          Text(campaign.title)
            .font(.title3.weight(.bold))
          Text(campaign.subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      HStack(alignment: .center, spacing: 18) {
        ZStack {
          Circle()
            .stroke(Color(.tertiarySystemFill), lineWidth: 10)
          Circle()
            .trim(from: 0, to: activityStore.progressFraction(for: campaign))
            .stroke(accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .animation(.easeInOut(duration: 0.25), value: progress.currentCount)

          VStack(spacing: 2) {
            Text("\(progress.currentCount)")
              .font(.title2.weight(.bold))
              .monospacedDigit()
            Text("/ \(campaign.targetCount)")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
        }
        .frame(width: 108, height: 108)

        VStack(alignment: .leading, spacing: 10) {
          ActivityStatChip(
            title: "本轮进度",
            value: "\(progress.currentCount)/\(campaign.targetCount)",
            hint: remaining == 0 ? "本轮已达标" : "还差 \(remaining) 次"
          )
          ActivityStatChip(
            title: "当前轮次",
            value: "第 \(progress.completedRounds + 1) 轮",
            hint: "进行中"
          )
          ActivityStatChip(
            title: "已完成轮次",
            value: "\(progress.completedRounds) 轮",
            hint: progress.completedRounds == 0 ? "尚未完成" : "已累计获奖"
          )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      HStack(spacing: 8) {
        Image(systemName: "gift.fill")
          .foregroundStyle(accent)
        VStack(alignment: .leading, spacing: 2) {
          Text(campaign.reward.title)
            .font(.subheadline.weight(.semibold))
          Text(campaign.reward.detail)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
        if let brand = campaign.reward.brandName, !brand.isEmpty {
          Text(brand)
            .font(.caption2.weight(.bold))
            .foregroundStyle(accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(accent.opacity(0.12), in: Capsule())
        }
      }
      .padding(12)
      .background(Color(.tertiarySystemFill).opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .padding(16)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

private struct ActivityStatChip: View {
  let title: String
  let value: String
  let hint: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.subheadline.weight(.semibold))
        .monospacedDigit()
      Text(hint)
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct ActivityRewardCard: View {
  let grant: ActivityRewardGrant
  var onClaim: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: grant.isClaimed ? "checkmark.seal.fill" : "ticket.fill")
        .font(.title3)
        .foregroundStyle(grant.isClaimed ? Color.secondary : Color(red: 0.18, green: 0.65, blue: 0.38))
        .frame(width: 36, height: 36)

      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(grant.rewardTitle)
            .font(.subheadline.weight(.semibold))
          Spacer()
          Text(grant.isClaimed ? "已领取" : "待领取")
            .font(.caption2.weight(.bold))
            .foregroundStyle(grant.isClaimed ? .secondary : Color(red: 0.18, green: 0.65, blue: 0.38))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
              (grant.isClaimed ? Color.secondary : Color(red: 0.18, green: 0.65, blue: 0.38))
                .opacity(0.12),
              in: Capsule()
            )
        }

        Text(grant.rewardDetail)
          .font(.caption)
          .foregroundStyle(.secondary)

        HStack(spacing: 8) {
          if let brand = grant.brandName, !brand.isEmpty {
            Text(brand)
          }
          Text("第 \(grant.roundIndex) 轮获得")
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)

        if !grant.isClaimed {
          Button("标记已领取", action: onClaim)
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 2)
        }
      }
    }
    .padding(14)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

/// 活动达标提示。
struct ActivityRewardToastModifier: ViewModifier {
  @EnvironmentObject private var activityStore: ActivityStore

  func body(content: Content) -> some View {
    content
      .alert(
        "活动奖励已到账",
        isPresented: Binding(
          get: { activityStore.latestRewardToast != nil },
          set: { if !$0 { activityStore.dismissRewardToast() } }
        )
      ) {
        Button("好的", role: .cancel) {
          activityStore.dismissRewardToast()
        }
      } message: {
        if let grant = activityStore.latestRewardToast {
          Text("\(grant.rewardTitle)\n\(grant.rewardDetail)\n进度已重新开始累计")
        }
      }
  }
}

extension View {
  func activityRewardToast() -> some View {
    modifier(ActivityRewardToastModifier())
  }
}
