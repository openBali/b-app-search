//
//  HomeAdPlacement.swift
//  b-app-search
//

import Foundation

/// 首页广告推荐位（品牌赞助 / 爆款推广）
struct HomeAdPlacement: Identifiable, Hashable, Codable {
  let id: String
  let sortOrder: Int
  let heroImageURL: URL
  let brandLogoURL: URL?
  let brandName: String
  let brandIntro: String
  let hotProductCopy: String
  let landingURL: URL?

  static let mockPlacements: [HomeAdPlacement] = [
    HomeAdPlacement(
      id: "ad-aurora-camp",
      sortOrder: 0,
      heroImageURL: URL(string: "https://picsum.photos/seed/ad-aurora/1200/720")!,
      brandLogoURL: URL(string: "https://picsum.photos/seed/logo-aurora/160/160"),
      brandName: "极光户外",
      brandIntro: "轻量化露营装备，陪你抵达更远的风景。",
      hotProductCopy: "超轻防风帐篷 Pro · 限时 8 折",
      landingURL: URL(string: "https://example.com/ads/aurora-camp")
    ),
    HomeAdPlacement(
      id: "ad-lumen-camera",
      sortOrder: 1,
      heroImageURL: URL(string: "https://picsum.photos/seed/ad-lumen/1200/720")!,
      brandLogoURL: URL(string: "https://picsum.photos/seed/logo-lumen/160/160"),
      brandName: "LUMEN 影像",
      brandIntro: "城市街拍与旅行记录，一套镜头覆盖日常创作。",
      hotProductCopy: "35mm 定焦旅行套装 · 赠滤镜包",
      landingURL: URL(string: "https://example.com/ads/lumen-camera")
    ),
    HomeAdPlacement(
      id: "ad-trail-bean",
      sortOrder: 2,
      heroImageURL: URL(string: "https://picsum.photos/seed/ad-trail/1200/720")!,
      brandLogoURL: URL(string: "https://picsum.photos/seed/logo-trail/160/160"),
      brandName: "山野豆仓",
      brandIntro: "精选单一产地咖啡豆，挂耳与冻干随心选。",
      hotProductCopy: "晨间唤醒挂耳礼盒 · 买二送一",
      landingURL: URL(string: "https://example.com/ads/trail-bean")
    )
  ]
}
