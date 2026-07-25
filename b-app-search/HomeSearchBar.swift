//
//  HomeSearchBar.swift
//  b-app-search
//

import PhotosUI
import SwiftUI
import UIKit

enum HomeSearchMode: Equatable {
  case text(String)
  case image
}

enum HomeSearchService {
  /// 支持按图片名称、标签、描述、类别，以及地理位置（地点名 / 经纬度文本）搜索。
  static func searchText(_ query: String, in images: [GalleryImage]) -> [GalleryImage] {
    let keyword = normalized(query)
    guard !keyword.isEmpty else { return [] }

    return images.filter { matches(image: $0, keyword: keyword) }
  }

  private static func normalized(_ query: String) -> String {
    query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private static func matches(image: GalleryImage, keyword: String) -> Bool {
    let searchableFields = [
      image.title,
      image.tag,
      image.description,
      image.category.displayName,
      image.locationLabel,
      image.locationName ?? "",
      coordinateSearchText(for: image)
    ]

    return searchableFields.contains { field in
      let value = field.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      guard !value.isEmpty else { return false }
      return value.contains(keyword)
    }
  }

  private static func coordinateSearchText(for image: GalleryImage) -> String {
    guard image.hasLocation else { return "" }
    return String(format: "%.4f,%.4f %.2f %.2f", image.latitude, image.longitude, image.latitude, image.longitude)
  }

  /// 本地演示回退；远程以图搜图请使用 `BackendAPI.Search.searchByImage`。
  static func searchByImage(in images: [GalleryImage]) -> [GalleryImage] {
    Array(images.shuffled().prefix(5))
  }
}

struct HomeSearchBar: View {
  var onActivate: () -> Void

  @Environment(\.appSkin) private var appSkin

  private var tokens: AppSkinTokens { appSkin.tokens }
  private var secondaryText: Color { tokens.secondaryText ?? Color.secondary }
  private var placeholderText: Color { secondaryText.opacity(0.72) }

  var body: some View {
    Button(action: onActivate) {
      HStack(spacing: 10) {
        Image(systemName: "magnifyingglass")
          .font(.body.weight(.medium))
          .foregroundStyle(secondaryText)

        Text("搜索名称、标签、地点…")
          .font(.body)
          .foregroundStyle(placeholderText)
          .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "photo.on.rectangle.angled")
          .font(.body.weight(.semibold))
          .foregroundStyle(tokens.accent)
          .frame(width: 32, height: 32)
          .background(tokens.accent.opacity(0.12), in: Circle())
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background {
        RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous)
          .fill(tokens.cardBackground)
          .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
      }
      .overlay {
        RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous)
          .strokeBorder(tokens.stroke, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("搜索图片")
    .accessibilityHint("展开搜索")
  }
}

struct HomeSearchInputBar: View {
  @Binding var searchText: String
  var isFocused: FocusState<Bool>.Binding

  @Environment(\.appSkin) private var appSkin
  @State private var selectedPhotoItem: PhotosPickerItem?

  private var tokens: AppSkinTokens { appSkin.tokens }
  private var primaryText: Color { tokens.primaryText ?? Color.primary }
  private var secondaryText: Color { tokens.secondaryText ?? Color.secondary }

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .font(.body.weight(.medium))
        .foregroundStyle(secondaryText)

      TextField("搜索名称、标签、地点…", text: $searchText)
        .textFieldStyle(.plain)
        .foregroundStyle(primaryText)
        .submitLabel(.search)
        .autocorrectionDisabled()
        .focused(isFocused)

      if !searchText.isEmpty {
        Button {
          searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(secondaryText.opacity(0.72))
        }
        .buttonStyle(.plain)
      }

      Rectangle()
        .fill(tokens.stroke)
        .frame(width: 1, height: 22)

      PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
        Image(systemName: "photo.on.rectangle.angled")
          .font(.body.weight(.semibold))
          .foregroundStyle(tokens.accent)
          .frame(width: 32, height: 32)
          .background(tokens.accent.opacity(0.12), in: Circle())
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background {
      RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous)
        .fill(tokens.cardBackground)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
    .overlay {
      RoundedRectangle(cornerRadius: tokens.cardCornerRadius, style: .continuous)
        .strokeBorder(tokens.stroke, lineWidth: 1)
    }
    .onChange(of: selectedPhotoItem) { newItem in
      guard let newItem else { return }
      Task {
        if let data = try? await newItem.loadTransferable(type: Data.self),
           let _ = UIImage(data: data)
        {
          await MainActor.run {
            selectedPhotoItem = nil
          }
        }
      }
    }
  }
}

struct HomeSearchResultsView: View {
  let mode: HomeSearchMode
  let results: [GalleryImage]
  var queryImage: UIImage?

  @Environment(\.dismiss) private var dismiss
  @State private var selectedMediaDestination: GalleryMediaOpenDestination?

  private var navigationTitle: String {
    switch mode {
    case .text(let query): return "「\(query)」的搜索结果"
    case .image: return "以图搜图"
    }
  }

  var body: some View {
    NavigationStack {
      Group {
        if results.isEmpty {
          VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
              .font(.system(size: 48))
              .foregroundStyle(.secondary)
            Text("未找到相关图片")
              .font(.headline)
            Text(emptyDescription)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 32)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          ScrollView {
            if mode == .image, let queryImage {
              HStack(spacing: 12) {
                Image(uiImage: queryImage)
                  .resizable()
                  .scaledToFill()
                  .frame(width: 56, height: 56)
                  .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                  Text("参考图片")
                    .font(.subheadline.weight(.semibold))
                  Text("已为你匹配相似内容（演示）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
              }
              .padding(.horizontal, 16)
              .padding(.top, 12)
            }

            LazyVStack(spacing: 12) {
              ForEach(results) { image in
                HomeSearchResultRow(image: image) {
                  selectedMediaDestination = .open(image, in: results)
                }
              }
            }
            .padding(16)
          }
        }
      }
      .navigationTitle(navigationTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("关闭") { dismiss() }
        }
      }
      .fullScreenCover(item: $selectedMediaDestination) { destination in
        GalleryMediaDestinationView(destination: destination)
      }
    }
  }

  private var emptyDescription: String {
    switch mode {
    case .text:
      return "可搜索图片名称、标签、地点名，或经纬度（如 39.90）；也可使用右侧按钮以图搜图"
    case .image:
      return "暂未匹配到相似图片，请换一张试试"
    }
  }
}

private struct HomeSearchResultRow: View {
  let image: GalleryImage
  var onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        AsyncImage(url: image.url) { phase in
          switch phase {
          case .success(let loaded):
            loaded.resizable().scaledToFill()
          default:
            Color(.tertiarySystemFill)
          }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

        VStack(alignment: .leading, spacing: 6) {
          Text(image.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
          HStack(spacing: 6) {
            Text(image.tag)
              .font(.caption)
              .foregroundStyle(image.category.pinColor)
            if image.hasLocation {
              Label(image.locationLabel, systemImage: "mappin")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
          Text(image.description)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(12)
      .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}
