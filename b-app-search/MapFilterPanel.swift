//
//  MapFilterPanel.swift
//  b-app-search
//

import SwiftUI

enum MapImageLocationFilter {
  static func country(for image: GalleryImage) -> String {
    if image.latitude >= 18, image.latitude <= 54,
       image.longitude >= 73, image.longitude <= 135
    {
      return "中国"
    }
    return "海外"
  }

  static func city(for image: GalleryImage) -> String {
    if image.latitude >= 39.4, image.latitude <= 41.1,
       image.longitude >= 115.7, image.longitude <= 117.4
    {
      return "北京"
    }

    if let locationName = image.locationName?.trimmingCharacters(in: .whitespacesAndNewlines),
       !locationName.isEmpty
    {
      if locationName.hasSuffix("区") || locationName.hasSuffix("县") {
        return "北京"
      }
      return locationName
    }

    return "其他城市"
  }
}

struct MapTopFilterPanel: View {
  let countries: [String]
  let cities: [String]
  @Binding var selectedCountries: Set<String>
  @Binding var selectedCities: Set<String>
  @Binding var expansion: CGFloat

  let maxHeight: CGFloat
  private let handleHeight: CGFloat = 36
  private let tint = Color(red: 0.22, green: 0.48, blue: 0.95)

  @State private var dragOriginExpansion: CGFloat = 0
  @State private var isDraggingPanel = false

  private var panelHeight: CGFloat {
    handleHeight + expansion * max(0, maxHeight - handleHeight)
  }

  var body: some View {
    VStack(spacing: 0) {
      panelHandle

      if expansion > 0.02 {
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            filterSection(title: "国家", options: countries, selection: $selectedCountries)
            filterSection(title: "城市", options: cities, selection: $selectedCities)

            if !selectedCountries.isEmpty || !selectedCities.isEmpty {
              Button("清除筛选") {
                withAnimation(.easeInOut(duration: 0.2)) {
                  selectedCountries.removeAll()
                  selectedCities.removeAll()
                }
              }
              .font(.caption.weight(.semibold))
              .foregroundStyle(tint)
            }
          }
          .padding(.horizontal, 16)
          .padding(.top, 4)
          .padding(.bottom, 16)
        }
        .frame(height: panelHeight - handleHeight)
      }
    }
    .frame(height: panelHeight, alignment: .top)
    .frame(maxWidth: .infinity)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    .gesture(panelDragGesture)
    .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: expansion)
  }

  private var panelHandle: some View {
    VStack(spacing: 6) {
      Capsule()
        .fill(Color.secondary.opacity(0.35))
        .frame(width: 36, height: 4)

      HStack(spacing: 4) {
        Image(systemName: "line.3.horizontal")
          .font(.caption.weight(.bold))
        Text("筛选")
          .font(.caption.weight(.semibold))
        if activeFilterCount > 0 {
          Text("\(activeFilterCount)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint, in: Capsule())
        }
      }
      .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .frame(height: handleHeight)
    .contentShape(Rectangle())
    .accessibilityLabel("展开地图筛选")
  }

  private var activeFilterCount: Int {
    selectedCountries.count + selectedCities.count
  }

  private func filterSection(
    title: String,
    options: [String],
    selection: Binding<Set<String>>
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.subheadline.weight(.semibold))

      if options.isEmpty {
        Text("暂无可筛选项")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        MapFilterChipGrid(options: options, selection: selection, tint: tint)
      }
    }
  }

  private var panelDragGesture: some Gesture {
    DragGesture(minimumDistance: 8)
      .onChanged { value in
        if !isDraggingPanel {
          dragOriginExpansion = expansion
          isDraggingPanel = true
        }

        let travel = max(maxHeight - handleHeight, 1)
        let delta = value.translation.height / travel
        expansion = min(max(dragOriginExpansion + delta, 0), 1)
      }
      .onEnded { value in
        isDraggingPanel = false
        let travel = max(maxHeight - handleHeight, 1)
        let predicted = dragOriginExpansion + value.predictedEndTranslation.height / travel

        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
          if predicted > 0.55 {
            expansion = 1
          } else if predicted < 0.25 {
            expansion = 0
          } else {
            expansion = expansion >= 0.5 ? 1 : 0
          }
        }
        dragOriginExpansion = expansion
      }
  }
}

private struct MapFilterChipGrid: View {
  let options: [String]
  @Binding var selection: Set<String>
  let tint: Color

  private let gap: CGFloat = 8

  var body: some View {
    GeometryReader { geometry in
      let columnCount = geometry.size.width >= 360 ? 3 : 2
      let rows = chunked(options, size: columnCount)

      VStack(spacing: gap) {
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
          HStack(spacing: gap) {
            ForEach(row, id: \.self) { option in
              chipButton(option)
            }

            if row.count < columnCount {
              ForEach(0..<(columnCount - row.count), id: \.self) { _ in
                Color.clear.frame(maxWidth: .infinity)
              }
            }
          }
        }
      }
      .frame(width: geometry.size.width, alignment: .leading)
    }
    .frame(height: estimatedHeight)
  }

  private var estimatedHeight: CGFloat {
    let columnCount: CGFloat = 3
    let rowCount = ceil(CGFloat(options.count) / columnCount)
    return rowCount * 34 + max(rowCount - 1, 0) * gap
  }

  private func chipButton(_ option: String) -> some View {
    let isSelected = selection.contains(option)

    return Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        if isSelected {
          selection.remove(option)
        } else {
          selection.insert(option)
        }
      }
    } label: {
      Text(option)
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
}
