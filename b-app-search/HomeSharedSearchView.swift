//
//  HomeSharedSearchView.swift
//  b-app-search
//

import SwiftUI

/// 首页内联搜索内容：已分享图片瀑布流，随输入实时过滤。
struct HomeInlineSearchContent: View {
  @EnvironmentObject private var galleryStore: GalleryStore

  @Binding var searchText: String
  @FocusState.Binding var isSearchFocused: Bool
  var horizontalInset: CGFloat = 16
  var onLocationTap: (GalleryImage) -> Void = { _ in }

  @State private var selectedMediaDestination: GalleryMediaOpenDestination?

  private var displayedImages: [GalleryImage] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    let allImages = galleryStore.publicImages
    guard !query.isEmpty else { return allImages }
    return HomeSearchService.searchText(query, in: allImages)
  }

  var body: some View {
    Group {
      if displayedImages.isEmpty {
        emptyState
      } else {
        ScrollView {
          GalleryWaterfallView(
            images: displayedImages,
            horizontalInset: horizontalInset,
            onImageTap: { selectedMediaDestination = .open($0, in: displayedImages) },
            onSimilarGroupTap: { group in
              guard let cover = group.first else { return }
              selectedMediaDestination = .open(cover, in: group)
            },
            onLocationTap: onLocationTap
          )
          .padding(.bottom, 24)
        }
      }
    }
    .fullScreenCover(item: $selectedMediaDestination) { destination in
      GalleryMediaDestinationView(
        destination: destination,
        onLocationTap: onLocationTap
      )
    }
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Spacer()
      Image(systemName: "magnifyingglass")
        .font(.system(size: 44))
        .foregroundStyle(.secondary)
      Text("未找到相关图片")
        .font(.headline)
      Text("可搜索图片名称、标签、地点名，或经纬度")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct HomeSharedSearchView_Previews: PreviewProvider {
  static var previews: some View {
    HomeInlineSearchContentPreviewHost()
      .environmentObject(GalleryStore.shared)
  }
}

private struct HomeInlineSearchContentPreviewHost: View {
  @State private var searchText = ""
  @FocusState private var isSearchFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      HomeSearchInputBar(searchText: $searchText, isFocused: $isSearchFocused)
        .padding(.horizontal, 16)
        .padding(.top, 8)
      HomeInlineSearchContent(
        searchText: $searchText,
        isSearchFocused: $isSearchFocused
      )
    }
    .background(Color(.systemGroupedBackground))
  }
}
