//
//  MapFilterPanel.swift
//  b-app-search
//

import SwiftUI

struct MapResolvedLocation: Hashable {
  let country: String
  let province: String?
  let city: String
}

/// 相对当前位置的距离筛选（单选）。
enum MapNearbyRadiusFilter: Double, CaseIterable, Identifiable {
  case five = 5
  case ten = 10
  case twenty = 20

  var id: Double { rawValue }

  var title: String {
    "最近\(Int(rawValue))km"
  }

  var meters: Double {
    rawValue * 1_000
  }
}

enum MapImageLocationFilter {
  static func resolve(_ image: GalleryImage) -> MapResolvedLocation {
    let country = country(for: image)
    guard country == "中国" else {
      return MapResolvedLocation(country: country, province: nil, city: "海外")
    }

    if let matched = matchCatalog(for: image) {
      return MapResolvedLocation(country: country, province: matched.province, city: matched.city)
    }

    return MapResolvedLocation(country: country, province: nil, city: "其他城市")
  }

  static func country(for image: GalleryImage) -> String {
    if image.latitude >= 18, image.latitude <= 54,
       image.longitude >= 73, image.longitude <= 135
    {
      return "中国"
    }
    return "海外"
  }

  static func province(for image: GalleryImage) -> String? {
    resolve(image).province
  }

  static func city(for image: GalleryImage) -> String {
    resolve(image).city
  }

  private static func matchCatalog(for image: GalleryImage) -> (province: String, city: String)? {
    // 北京坐标框
    if image.latitude >= 39.4, image.latitude <= 41.1,
       image.longitude >= 115.7, image.longitude <= 117.4
    {
      return ("北京市", "北京")
    }

    let rawName = image.locationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !rawName.isEmpty {
      if ChinaRegionCatalog.beijingDistricts.contains(rawName) {
        return ("北京市", "北京")
      }

      // 名称中包含城市名（优先长匹配）
      let cities = ChinaRegionCatalog.allCities().sorted { $0.count > $1.count }
      for city in cities {
        if rawName.contains(city),
           let province = ChinaRegionCatalog.province(containingCity: city)
        {
          return (province.name, city)
        }
      }

      // 名称中包含省份名
      for province in ChinaRegionCatalog.provinces {
        let shortName = province.name
          .replacingOccurrences(of: "省", with: "")
          .replacingOccurrences(of: "市", with: "")
          .replacingOccurrences(of: "壮族自治区", with: "")
          .replacingOccurrences(of: "回族自治区", with: "")
          .replacingOccurrences(of: "维吾尔自治区", with: "")
          .replacingOccurrences(of: "自治区", with: "")
          .replacingOccurrences(of: "特别行政区", with: "")
        if rawName.contains(province.name) || (!shortName.isEmpty && rawName.contains(shortName)) {
          if let firstCity = province.cities.first {
            return (province.name, firstCity)
          }
        }
      }
    }

    return nil
  }
}

struct MapTopFilterPanel: View {
  let countries: [String]
  @Binding var selectedCountries: Set<String>
  @Binding var selectedProvinces: Set<String>
  @Binding var selectedCities: Set<String>
  @Binding var selectedCategories: Set<GalleryImageCategory>
  @Binding var selectedNearbyRadius: MapNearbyRadiusFilter?
  @Binding var expansion: CGFloat
  /// 是否已拿到用户定位，用于距离筛选项提示。
  var hasUserLocation: Bool = true

  let maxHeight: CGFloat
  private let handleHeight: CGFloat = 40
  private let tint = Color(red: 0.22, green: 0.48, blue: 0.95)
  private let sectionSpacing: CGFloat = 16
  private let contentInset: CGFloat = 14

  @State private var dragOriginExpansion: CGFloat = 0
  @State private var isDraggingPanel = false
  @State private var showCityPicker = false

  private var panelHeight: CGFloat {
    handleHeight + expansion * max(0, maxHeight - handleHeight)
  }

  var body: some View {
    VStack(spacing: 0) {
      panelHandle

      if expansion > 0.02 {
        ScrollView {
          VStack(alignment: .leading, spacing: sectionSpacing) {
            categorySection
            nearbyRadiusSection
            filterSection(title: "国家", options: countries, selection: $selectedCountries)
            cityFilterEntry

            if hasActiveFilters {
              Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                  clearAllFilters()
                }
              } label: {
                Text("清除筛选")
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(tint)
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 10)
                  .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
              }
              .buttonStyle(.plain)
              .padding(.top, 2)
            }
          }
          .padding(.horizontal, contentInset)
          .padding(.top, 8)
          .padding(.bottom, 18)
        }
        .frame(height: panelHeight - handleHeight)
      }
    }
    .frame(height: panelHeight, alignment: .top)
    .frame(maxWidth: .infinity)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    .gesture(panelDragGesture)
    .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: expansion)
    .sheet(isPresented: $showCityPicker) {
      MapCityPickerSheet(
        selectedProvinces: $selectedProvinces,
        selectedCities: $selectedCities
      )
      .presentationDetents([.medium, .large])
      .presentationDragIndicator(.visible)
    }
  }

  private var categorySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("标签")

      LazyVGrid(
        columns: [
          GridItem(.flexible(), spacing: 8),
          GridItem(.flexible(), spacing: 8)
        ],
        spacing: 8
      ) {
        ForEach(GalleryImageCategory.allCases) { category in
          categoryChip(category)
        }
      }
    }
  }

  private func categoryChip(_ category: GalleryImageCategory) -> some View {
    let isSelected = selectedCategories.contains(category)

    return Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        if isSelected {
          selectedCategories.remove(category)
        } else {
          selectedCategories.insert(category)
        }
      }
    } label: {
      HStack(spacing: 8) {
        Circle()
          .fill(category.pinColor)
          .frame(width: 10, height: 10)
          .overlay {
            Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1)
          }

        Image(systemName: category.iconName)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(isSelected ? category.pinColor : .secondary)

        Text(category.displayName)
          .font(.caption.weight(.semibold))
          .foregroundStyle(isSelected ? .primary : .secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.85)

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 10)
      .background(
        isSelected ? category.pinColor.opacity(0.14) : Color(.secondarySystemGroupedBackground),
        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(isSelected ? category.pinColor.opacity(0.4) : Color.clear, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
  }

  private var nearbyRadiusSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("附近")

      HStack(spacing: 8) {
        ForEach(MapNearbyRadiusFilter.allCases) { radius in
          let isSelected = selectedNearbyRadius == radius
          Button {
            withAnimation(.easeInOut(duration: 0.2)) {
              selectedNearbyRadius = isSelected ? nil : radius
            }
          } label: {
            Text(radius.title)
              .font(.caption.weight(.semibold))
              .foregroundStyle(isSelected ? tint : .secondary)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
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
      }

      if selectedNearbyRadius != nil, !hasUserLocation {
        Text("需要开启定位后才能按距离筛选")
          .font(.caption2)
          .foregroundStyle(.orange)
          .padding(.top, 2)
      }
    }
  }

  private var cityFilterEntry: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("城市")

      Button {
        showCityPicker = true
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "building.2")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

          VStack(alignment: .leading, spacing: 2) {
            Text(citySummaryTitle)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.primary)
              .lineLimit(1)
            Text("中国 · 省份 / 城市")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }

          Spacer(minLength: 8)

          if regionFilterCount > 0 {
            Text("\(regionFilterCount)")
              .font(.caption2.weight(.bold))
              .foregroundStyle(.white)
              .padding(.horizontal, 7)
              .padding(.vertical, 3)
              .background(tint, in: Capsule())
          }

          Image(systemName: "chevron.up")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
      .buttonStyle(.plain)
    }
  }

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.primary)
  }

  private var citySummaryTitle: String {
    if selectedCities.isEmpty, selectedProvinces.isEmpty {
      return "选择省份或城市"
    }
    if !selectedCities.isEmpty {
      let sorted = selectedCities.sorted()
      if sorted.count <= 2 {
        return sorted.joined(separator: "、")
      }
      return "\(sorted.prefix(2).joined(separator: "、")) 等\(sorted.count)个城市"
    }
    let sorted = selectedProvinces.sorted()
    if sorted.count <= 2 {
      return sorted.joined(separator: "、")
    }
    return "\(sorted.prefix(2).joined(separator: "、")) 等\(sorted.count)个省份"
  }

  private var regionFilterCount: Int {
    selectedProvinces.count + selectedCities.count
  }

  private var hasActiveFilters: Bool {
    !selectedCountries.isEmpty
      || !selectedProvinces.isEmpty
      || !selectedCities.isEmpty
      || !selectedCategories.isEmpty
      || selectedNearbyRadius != nil
  }

  private var panelHandle: some View {
    VStack(spacing: 6) {
      Capsule()
        .fill(Color.secondary.opacity(0.35))
        .frame(width: 36, height: 4)
        .padding(.top, 8)

      HStack(spacing: 6) {
        Image(systemName: "line.3.horizontal.decrease.circle")
          .font(.caption.weight(.semibold))
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
        Spacer(minLength: 0)
      }
      .foregroundStyle(.secondary)
      .padding(.horizontal, contentInset)
      .padding(.bottom, 8)
    }
    .frame(maxWidth: .infinity)
    .frame(height: handleHeight)
    .contentShape(Rectangle())
    .accessibilityLabel("展开地图筛选")
  }

  private var activeFilterCount: Int {
    selectedCountries.count
      + selectedProvinces.count
      + selectedCities.count
      + selectedCategories.count
      + (selectedNearbyRadius == nil ? 0 : 1)
  }

  private func clearAllFilters() {
    selectedCountries.removeAll()
    selectedProvinces.removeAll()
    selectedCities.removeAll()
    selectedCategories.removeAll()
    selectedNearbyRadius = nil
  }

  private func filterSection(
    title: String,
    options: [String],
    selection: Binding<Set<String>>
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader(title)

      if options.isEmpty {
        Text("暂无可筛选项")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.vertical, 4)
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

/// 底部弹出：中国 → 省份 → 城市 多选列表
struct MapCityPickerSheet: View {
  @Binding var selectedProvinces: Set<String>
  @Binding var selectedCities: Set<String>
  @Environment(\.dismiss) private var dismiss

  @State private var query = ""
  private let tint = Color(red: 0.22, green: 0.48, blue: 0.95)

  private var filteredProvinces: [ChinaProvince] {
    let key = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty else { return ChinaRegionCatalog.provinces }
    return ChinaRegionCatalog.provinces.compactMap { province in
      if province.name.contains(key) {
        return province
      }
      let cities = province.cities.filter { $0.contains(key) }
      guard !cities.isEmpty else { return nil }
      return ChinaProvince(name: province.name, cities: cities)
    }
  }

  var body: some View {
    NavigationStack {
      List {
        if !selectedProvinces.isEmpty || !selectedCities.isEmpty {
          Section {
            Button("清除已选省份/城市") {
              selectedProvinces.removeAll()
              selectedCities.removeAll()
            }
            .foregroundStyle(tint)
          }
        }

        ForEach(filteredProvinces) { province in
          Section {
            Button {
              toggleProvince(province)
            } label: {
              HStack {
                Text("全省")
                  .font(.subheadline.weight(.semibold))
                Spacer()
                provinceSelectionMark(for: province)
              }
            }
            .buttonStyle(.plain)

            ForEach(province.cities, id: \.self) { city in
              Button {
                toggleCity(city, in: province)
              } label: {
                HStack {
                  Text(city)
                    .foregroundStyle(.primary)
                  Spacer()
                  if selectedCities.contains(city) || selectedProvinces.contains(province.name) {
                    Image(systemName: "checkmark")
                      .font(.subheadline.weight(.bold))
                      .foregroundStyle(tint)
                  }
                }
              }
              .buttonStyle(.plain)
            }
          } header: {
            Text(province.name)
          }
        }
      }
      .listStyle(.insetGrouped)
      .searchable(text: $query, prompt: "搜索省份或城市")
      .navigationTitle("选择城市")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("关闭") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") { dismiss() }
            .fontWeight(.semibold)
        }
      }
    }
  }

  @ViewBuilder
  private func provinceSelectionMark(for province: ChinaProvince) -> some View {
    if selectedProvinces.contains(province.name) {
      Text("已选全省")
        .font(.caption2.weight(.bold))
        .foregroundStyle(tint)
    } else if province.cities.contains(where: { selectedCities.contains($0) }) {
      Text("部分城市")
        .font(.caption2)
        .foregroundStyle(.secondary)
    } else {
      Text("选择")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  private func toggleProvince(_ province: ChinaProvince) {
    if selectedProvinces.contains(province.name) {
      selectedProvinces.remove(province.name)
    } else {
      selectedProvinces.insert(province.name)
      // 选全省时清掉该省下单独城市，避免重复
      for city in province.cities {
        selectedCities.remove(city)
      }
    }
  }

  private func toggleCity(_ city: String, in province: ChinaProvince) {
    // 若已选全省，先退出全省模式再单选城市
    if selectedProvinces.contains(province.name) {
      selectedProvinces.remove(province.name)
      selectedCities.formUnion(province.cities)
      selectedCities.remove(city)
      return
    }

    if selectedCities.contains(city) {
      selectedCities.remove(city)
    } else {
      selectedCities.insert(city)
      // 若该省全部城市都选中，升级为全省
      if province.cities.allSatisfy({ selectedCities.contains($0) }) {
        selectedProvinces.insert(province.name)
        for item in province.cities {
          selectedCities.remove(item)
        }
      }
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
    let rowCount = ceil(CGFloat(max(options.count, 1)) / columnCount)
    return rowCount * 36 + max(rowCount - 1, 0) * gap
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
        .padding(.vertical, 10)
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
