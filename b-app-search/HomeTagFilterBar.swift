//
//  HomeTagFilterBar.swift
//  b-app-search
//

import SwiftUI

enum HomeImageFilterTags {
  static let all = ["城市", "自然", "户外", "风光", "街拍", "建筑", "植物"]
}

enum HomeTagFilterBarLayout {
  /// 根据屏幕高度限制可见行数，超出后滚动（原首页内联样式）
  case adaptive
  /// 在弹窗/设置页中展示完整列表，不裁切高度
  case expanded
}

struct HomeTagFilterBar: View {
  let tags: [String]
  @Binding var selectedTags: Set<String>
  let tint: Color
  var layout: HomeTagFilterBarLayout = .adaptive

  private let columnGap: CGFloat = 8
  private let rowGap: CGFloat = 8
  private let chipHeight: CGFloat = 34
  private let sectionHeaderHeight: CGFloat = 22

  var body: some View {
    Group {
      switch layout {
      case .adaptive:
        adaptiveBody
      case .expanded:
        expandedBody
      }
    }
  }

  private var adaptiveBody: some View {
    GeometryReader { geometry in
      let columnCount = columnCount(for: geometry.size.width)
      let screenHeight = UIScreen.main.bounds.height
      let maxRows = maxVisibleRows(for: screenHeight)
      let totalRows = rowCount(tagCount: tags.count, columnCount: columnCount)
      let needsScroll = totalRows > maxRows
      let viewportHeight = scrollViewportHeight(maxRows: maxRows, needsSections: needsScroll)

      if needsScroll {
        scrollableTagList(columnCount: columnCount, viewportHeight: viewportHeight)
          .frame(width: geometry.size.width, alignment: .leading)
      } else {
        staticTagGrid(columnCount: columnCount)
          .frame(width: geometry.size.width, alignment: .leading)
      }
    }
    .frame(height: resolvedHeight)
  }

  private var expandedBody: some View {
    let width = max(UIScreen.main.bounds.width - 40, 280)
    let columnCount = columnCount(for: width)

    return ScrollView(.vertical, showsIndicators: true) {
      expandedTagList(columnCount: columnCount)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
  }

  private func expandedTagList(columnCount: Int) -> some View {
    let sections = pinyinSections(from: tags)

    return Group {
      if sections.count > 1 {
        LazyVStack(alignment: .leading, spacing: 10, pinnedViews: [.sectionHeaders]) {
          ForEach(sections) { section in
            Section {
              tagGrid(section.tags, columnCount: columnCount)
            } header: {
              sectionHeader(section.letter)
            }
          }
        }
      } else {
        staticTagGrid(columnCount: columnCount)
      }
    }
  }

  private var resolvedHeight: CGFloat {
    let width = UIScreen.main.bounds.width - 40
    let columnCount = columnCount(for: max(width, 280))
    let screenHeight = UIScreen.main.bounds.height
    let maxRows = maxVisibleRows(for: screenHeight)
    let totalRows = rowCount(tagCount: tags.count, columnCount: columnCount)
    let needsScroll = totalRows > maxRows

    if needsScroll {
      return scrollViewportHeight(maxRows: maxRows, needsSections: true)
    }

    return CGFloat(totalRows) * chipHeight + CGFloat(max(totalRows - 1, 0)) * rowGap
  }

  // MARK: - Layout

  private func scrollableTagList(columnCount: Int, viewportHeight: CGFloat) -> some View {
    let sections = pinyinSections(from: tags)

    return ScrollViewReader { proxy in
      HStack(alignment: .top, spacing: 2) {
        ScrollView(.vertical, showsIndicators: true) {
          LazyVStack(alignment: .leading, spacing: 10, pinnedViews: [.sectionHeaders]) {
            ForEach(sections) { section in
              Section {
                tagGrid(section.tags, columnCount: columnCount)
              } header: {
                sectionHeader(section.letter)
              }
              .id(section.id)
            }
          }
          .padding(.trailing, 4)
        }
        .frame(height: viewportHeight)

        if sections.count > 1 {
          pinyinIndexBar(sections: sections) { sectionID in
            withAnimation(.easeInOut(duration: 0.2)) {
              proxy.scrollTo(sectionID, anchor: .top)
            }
          }
        }
      }
    }
  }

  private func staticTagGrid(columnCount: Int) -> some View {
    let rows = chunked(tags, size: columnCount)

    return VStack(spacing: rowGap) {
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        HStack(spacing: columnGap) {
          ForEach(row, id: \.self) { tag in
            tagButton(tag)
          }

          if row.count < columnCount {
            ForEach(0..<(columnCount - row.count), id: \.self) { _ in
              Color.clear
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
            }
          }
        }
      }
    }
  }

  private func tagGrid(_ sectionTags: [String], columnCount: Int) -> some View {
    let rows = chunked(sectionTags, size: columnCount)

    return VStack(spacing: rowGap) {
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        HStack(spacing: columnGap) {
          ForEach(row, id: \.self) { tag in
            tagButton(tag)
          }

          if row.count < columnCount {
            ForEach(0..<(columnCount - row.count), id: \.self) { _ in
              Color.clear
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
            }
          }
        }
      }
    }
  }

  private func sectionHeader(_ letter: String) -> some View {
    Text(letter)
      .font(.caption.weight(.bold))
      .foregroundStyle(tint)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 2)
      .background(Color(.systemGroupedBackground))
  }

  private func pinyinIndexBar(
    sections: [HomeTagPinyinSection],
    scrollTo: @escaping (String) -> Void
  ) -> some View {
    VStack(spacing: 2) {
      ForEach(sections) { section in
        Button {
          scrollTo(section.id)
        } label: {
          Text(section.letter)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(tint.opacity(0.85))
            .frame(width: 14, height: 12)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.vertical, 2)
    .accessibilityLabel("拼音索引")
  }

  private func tagButton(_ tag: String) -> some View {
    let isSelected = selectedTags.contains(tag)

    return Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        if isSelected {
          selectedTags.remove(tag)
        } else {
          selectedTags.insert(tag)
        }
      }
    } label: {
      Text(tag)
        .font(.caption.weight(.semibold))
        .foregroundStyle(isSelected ? tint : .secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
          isSelected ? tint.opacity(0.14) : Color(.secondarySystemGroupedBackground),
          in: Capsule()
        )
        .overlay {
          Capsule()
            .stroke(isSelected ? tint.opacity(0.35) : Color.clear, lineWidth: 1)
        }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(tag)标签")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  // MARK: - Metrics

  private func columnCount(for width: CGFloat) -> Int {
    if width >= 430 { return 4 }
    if width >= 360 { return 4 }
    return 3
  }

  private func maxVisibleRows(for screenHeight: CGFloat) -> Int {
    if screenHeight < 700 { return 2 }
    if screenHeight < 820 { return 3 }
    if screenHeight < 920 { return 3 }
    return 4
  }

  private func rowCount(tagCount: Int, columnCount: Int) -> Int {
    guard tagCount > 0, columnCount > 0 else { return 0 }
    return Int(ceil(Double(tagCount) / Double(columnCount)))
  }

  private func scrollViewportHeight(maxRows: Int, needsSections: Bool) -> CGFloat {
    let gridHeight = CGFloat(maxRows) * chipHeight + CGFloat(max(maxRows - 1, 0)) * rowGap
    return needsSections ? gridHeight + sectionHeaderHeight : gridHeight
  }

  private func chunked(_ items: [String], size: Int) -> [[String]] {
    guard size > 0 else { return [] }
    var rows: [[String]] = []
    var index = 0
    while index < items.count {
      let end = min(index + size, items.count)
      rows.append(Array(items[index..<end]))
      index = end
    }
    return rows
  }

  private func pinyinSections(from tags: [String]) -> [HomeTagPinyinSection] {
    let sorted = tags.sorted {
      $0.homePinyinSortKey.localizedCompare($1.homePinyinSortKey) == .orderedAscending
    }

    var sections: [HomeTagPinyinSection] = []
    var currentLetter = ""
    var bucket: [String] = []

    for tag in sorted {
      let letter = tag.homePinyinSectionLetter
      if letter != currentLetter {
        if !bucket.isEmpty {
          sections.append(HomeTagPinyinSection(letter: currentLetter, tags: bucket))
        }
        currentLetter = letter
        bucket = [tag]
      } else {
        bucket.append(tag)
      }
    }

    if !bucket.isEmpty {
      sections.append(HomeTagPinyinSection(letter: currentLetter, tags: bucket))
    }

    return sections
  }
}

private struct HomeTagPinyinSection: Identifiable {
  let letter: String
  let tags: [String]

  var id: String { letter }
}

extension String {
  var homePinyinSortKey: String {
    let mutable = NSMutableString(string: self)
    CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
    CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
    return (mutable as String).lowercased()
  }

  var homePinyinSectionLetter: String {
    let key = homePinyinSortKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let first = key.first else { return "#" }
    if first.isLetter {
      return String(first).uppercased()
    }
    return "#"
  }
}
