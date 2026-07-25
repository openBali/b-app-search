//
//  MapView.swift
//  b-app-search
//

import MapKit
import SwiftUI

/// 地图缩放较小时合并邻近图片，只展示数量；放大后展示单点样式。
struct GalleryImageCluster: Identifiable, Hashable {
  let id: String
  let coordinate: CLLocationCoordinate2D
  let images: [GalleryImage]

  var count: Int { images.count }

  static func == (lhs: GalleryImageCluster, rhs: GalleryImageCluster) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

private enum MapPinDisplayItem: Identifiable {
  case image(GalleryImage)
  case cluster(GalleryImageCluster)
  case focus(GalleryImage)

  var id: String {
    switch self {
    case .image(let image):
      return "image-\(image.id)"
    case .cluster(let cluster):
      return "cluster-\(cluster.id)"
    case .focus(let image):
      return "focus-\(image.id)"
    }
  }

  var coordinate: CLLocationCoordinate2D {
    switch self {
    case .image(let image):
      return image.coordinate
    case .cluster(let cluster):
      return cluster.coordinate
    case .focus(let image):
      return image.coordinate
    }
  }
}

struct MapView: View {
  @EnvironmentObject private var galleryStore: GalleryStore
  @EnvironmentObject private var mapFocus: MapFocusController
  @StateObject private var locationManager = MapLocationManager()
  @State private var region = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
  )
  @State private var selectedImage: GalleryImage?
  @State private var selectedMediaDestination: GalleryMediaOpenDestination?
  @State private var selectedCountries: Set<String> = []
  @State private var selectedCities: Set<String> = []
  @State private var filterPanelExpansion: CGFloat = 0

  private var allImagePins: [GalleryImage] {
    galleryStore.galleryImages.filter(\.hasLocation)
  }

  private var imagePins: [GalleryImage] {
    allImagePins.filter { image in
      let country = MapImageLocationFilter.country(for: image)
      let city = MapImageLocationFilter.city(for: image)
      let countryMatch = selectedCountries.isEmpty || selectedCountries.contains(country)
      let cityMatch = selectedCities.isEmpty || selectedCities.contains(city)
      return countryMatch && cityMatch
    }
  }

  private var availableCountries: [String] {
    Array(Set(allImagePins.map(MapImageLocationFilter.country(for:)))).sorted()
  }

  private var availableCities: [String] {
    Array(Set(allImagePins.map(MapImageLocationFilter.city(for:)))).sorted()
  }
  /// 比例尺较大（视野较小）时展示单点；比例尺较小时展示聚合数量
  private let detailedPinSpanThreshold: Double = 0.035

  private var showDetailedPins: Bool {
    region.span.latitudeDelta <= detailedPinSpanThreshold
  }

  private var mapPinItems: [MapPinDisplayItem] {
    if showDetailedPins {
      return imagePins.map { .image($0) }
    }
    return clusterImages(imagePins, span: region.span).map { .cluster($0) }
  }

  private var mapAnnotationItems: [MapPinDisplayItem] {
    var items = mapPinItems
    if let focused = focusedImage, !showDetailedPins {
      items.append(.focus(focused))
    }
    return items
  }

  private var focusedImage: GalleryImage? {
    guard let id = mapFocus.focusedImageID else { return nil }
    return imagePins.first(where: { $0.id == id })
  }

  private var activeCategories: [GalleryImageCategory] {
    Array(Set(imagePins.map(\.category))).sorted { $0.displayName < $1.displayName }
  }

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        let maxPanelHeight = geometry.size.height * 0.5

        ZStack(alignment: .bottom) {
          Map(
            coordinateRegion: $region,
            showsUserLocation: true,
            annotationItems: mapAnnotationItems
          ) { item in
            MapAnnotation(coordinate: item.coordinate) {
              switch item {
              case .image(let image):
                ImageMapPointerPin(
                  image: image,
                  isSelected: isHighlighted(image)
                )
                .onTapGesture {
                  withAnimation(.easeInOut(duration: 0.2)) {
                    selectedImage = image
                    mapFocus.focus(on: image)
                  }
                }
              case .cluster(let cluster):
                MapImageClusterPin(count: cluster.count)
                  .onTapGesture {
                    zoomToCluster(cluster)
                  }
              case .focus(let image):
                MapFocusCoordinateHighlight(image: image)
              }
            }
          }
          .ignoresSafeArea(edges: .bottom)

          VStack(spacing: 0) {
            MapTopFilterPanel(
              countries: availableCountries,
              cities: availableCities,
              selectedCountries: $selectedCountries,
              selectedCities: $selectedCities,
              expansion: $filterPanelExpansion,
              maxHeight: maxPanelHeight
            )
            .padding(.horizontal, 12)
            .padding(.top, 4)

            HStack {
              Spacer()
              Button {
                centerOnUserLocation()
              } label: {
                Image(systemName: "location.fill")
                  .font(.body.weight(.semibold))
                  .foregroundStyle(.primary)
                  .frame(width: 44, height: 44)
                  .background(.regularMaterial, in: Circle())
                  .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
              }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            if let image = selectedImage {
              VStack(spacing: 8) {
                MapImageCalloutCard(
                  image: image,
                  onDismiss: {
                    selectedImage = nil
                    mapFocus.clearFocus()
                  },
                  onPreview: { selectedMediaDestination = .open(image, in: imagePins) }
                )
                .frame(maxWidth: .infinity)

                if image.hasLocation {
                  MapLocationActionBar(
                    image: image,
                    userCoordinate: locationManager.userCoordinate
                  )
                  .frame(maxWidth: .infinity, alignment: .trailing)
                }
              }
              .padding(.horizontal, 16)
              .padding(.bottom, 10)
              .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: 12) {
              MapPointerLayerLegend(categories: activeCategories)
              Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
          }
        }
      }
      .navigationBarHidden(true)
      .onAppear {
        locationManager.requestAuthorization()
        if mapFocus.focusedImageID == nil {
          fitRegionToImagePins()
        } else {
          applyFocusedImageIfNeeded()
        }
      }
      .onChange(of: mapFocus.focusedImageID) { _ in
        applyFocusedImageIfNeeded()
      }
      .onReceive(locationManager.$userCoordinate) { coordinate in
        guard let coordinate, selectedImage == nil, mapFocus.focusedImageID == nil else { return }
        region.center = coordinate
      }
      .onChange(of: showDetailedPins) { isDetailed in
        if !isDetailed, mapFocus.focusedImageID == nil {
          selectedImage = nil
        }
      }
      .onChange(of: selectedCountries) { _ in
        syncSelectionAfterFilterChange()
      }
      .onChange(of: selectedCities) { _ in
        syncSelectionAfterFilterChange()
      }
      .fullScreenCover(item: $selectedMediaDestination) { destination in
        GalleryMediaDestinationView(destination: destination)
      }
    }
  }

  private func isHighlighted(_ image: GalleryImage) -> Bool {
    selectedImage?.id == image.id || mapFocus.focusedImageID == image.id
  }

  private func syncSelectionAfterFilterChange() {
    guard let selected = selectedImage, !imagePins.contains(where: { $0.id == selected.id }) else {
      return
    }
    selectedImage = nil
    mapFocus.clearFocus()
  }

  private func applyFocusedImageIfNeeded() {
    guard let image = focusedImage else { return }
    withAnimation(.easeInOut(duration: 0.35)) {
      region.center = image.coordinate
      region.span = MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
      selectedImage = image
    }
  }

  private func centerOnUserLocation() {
    if let coordinate = locationManager.userCoordinate {
      withAnimation {
        region.center = coordinate
        region.span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
      }
    } else {
      locationManager.requestAuthorization()
    }
  }

  private func fitRegionToImagePins() {
    let coordinates = imagePins.map(\.coordinate)
    guard let first = coordinates.first else { return }

    var minLat = first.latitude
    var maxLat = first.latitude
    var minLon = first.longitude
    var maxLon = first.longitude

    for coordinate in coordinates {
      minLat = min(minLat, coordinate.latitude)
      maxLat = max(maxLat, coordinate.latitude)
      minLon = min(minLon, coordinate.longitude)
      maxLon = max(maxLon, coordinate.longitude)
    }

    let center = CLLocationCoordinate2D(
      latitude: (minLat + maxLat) / 2,
      longitude: (minLon + maxLon) / 2
    )
    let span = MKCoordinateSpan(
      latitudeDelta: max((maxLat - minLat) * 1.5, 0.06),
      longitudeDelta: max((maxLon - minLon) * 1.5, 0.06)
    )
    region = MKCoordinateRegion(center: center, span: span)
  }

  private func clusterImages(
    _ images: [GalleryImage],
    span: MKCoordinateSpan
  ) -> [GalleryImageCluster] {
    let cellSize = max(span.latitudeDelta / 5, 0.012)
    var buckets: [String: [GalleryImage]] = [:]

    for image in images {
      let latBucket = Int(floor(image.latitude / cellSize))
      let lonBucket = Int(floor(image.longitude / cellSize))
      let key = "\(latBucket)_\(lonBucket)"
      buckets[key, default: []].append(image)
    }

    return buckets.map { key, groupedImages in
      let avgLat = groupedImages.map(\.latitude).reduce(0, +) / Double(groupedImages.count)
      let avgLon = groupedImages.map(\.longitude).reduce(0, +) / Double(groupedImages.count)
      return GalleryImageCluster(
        id: key,
        coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
        images: groupedImages
      )
    }
  }

  private func zoomToCluster(_ cluster: GalleryImageCluster) {
    let coordinates = cluster.images.map(\.coordinate)
    guard let first = coordinates.first else { return }

    var minLat = first.latitude
    var maxLat = first.latitude
    var minLon = first.longitude
    var maxLon = first.longitude

    for coordinate in coordinates {
      minLat = min(minLat, coordinate.latitude)
      maxLat = max(maxLat, coordinate.latitude)
      minLon = min(minLon, coordinate.longitude)
      maxLon = max(maxLon, coordinate.longitude)
    }

    withAnimation(.easeInOut(duration: 0.35)) {
      region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
          latitude: (minLat + maxLat) / 2,
          longitude: (minLon + maxLon) / 2
        ),
        span: MKCoordinateSpan(
          latitudeDelta: max((maxLat - minLat) * 2.2, detailedPinSpanThreshold * 0.85),
          longitudeDelta: max((maxLon - minLon) * 2.2, detailedPinSpanThreshold * 0.85)
        )
      )
    }
  }
}

// MARK: - Focus highlight (cluster zoom level)

private struct MapFocusCoordinateHighlight: View {
  let image: GalleryImage

  @State private var pulse = false

  var body: some View {
    ZStack {
      Circle()
        .stroke(image.category.pinColor.opacity(0.35), lineWidth: 3)
        .frame(width: pulse ? 58 : 44, height: pulse ? 58 : 44)
        .opacity(pulse ? 0.15 : 0.55)

      Circle()
        .fill(image.category.pinColor)
        .frame(width: 16, height: 16)
        .overlay {
          Circle()
            .strokeBorder(.white, lineWidth: 2)
        }
        .shadow(color: image.category.pinColor.opacity(0.45), radius: 6, y: 2)
    }
    .onAppear {
      withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
        pulse = true
      }
    }
  }
}

// MARK: - Cluster pin

private struct MapImageClusterPin: View {
  let count: Int

  var body: some View {
    ZStack {
      Circle()
        .fill(Color(red: 0.22, green: 0.48, blue: 0.95))
        .frame(width: 42, height: 42)
        .overlay {
          Circle()
            .strokeBorder(.white, lineWidth: 2.5)
        }
        .shadow(color: Color(red: 0.22, green: 0.48, blue: 0.95).opacity(0.4), radius: 6, y: 3)

      Text("\(count)")
        .font(.subheadline.weight(.bold))
        .foregroundStyle(.white)
    }
  }
}

// MARK: - Google-style pointer pin

struct ImageMapPointerPin: View {
  let image: GalleryImage
  var isSelected: Bool = false

  private var pinScale: CGFloat { isSelected ? 1.12 : 1 }

  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        Circle()
          .fill(image.category.pinColor)
          .frame(width: isSelected ? 40 : 34, height: isSelected ? 40 : 34)
          .overlay {
            Circle()
              .strokeBorder(.white, lineWidth: 2.5)
          }
          .shadow(color: image.category.pinColor.opacity(0.45), radius: isSelected ? 8 : 4, y: 3)

        Image(systemName: image.category.iconName)
          .font(.system(size: isSelected ? 15 : 13, weight: .bold))
          .foregroundStyle(.white)
      }

      MapPointerPinTail()
        .fill(image.category.pinColor)
        .frame(width: 14, height: 10)
        .overlay {
          MapPointerPinTail()
            .stroke(.white, lineWidth: 2)
            .frame(width: 14, height: 10)
        }
        .offset(y: -2)

      if isSelected {
        Text(image.title)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.regularMaterial, in: Capsule())
          .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
          .padding(.top, 4)
      }
    }
    .scaleEffect(pinScale)
    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
  }
}

private struct MapPointerPinTail: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX - rect.width / 2, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.midX + rect.width / 2, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}

// MARK: - Legend

private struct MapPointerLayerLegend: View {
  let categories: [GalleryImageCategory]

  var body: some View {
    FlowLayout(spacing: 6) {
      ForEach(categories) { category in
        HStack(spacing: 5) {
          Circle()
            .fill(category.pinColor)
            .frame(width: 9, height: 9)
            .overlay {
              Circle().strokeBorder(.white, lineWidth: 1)
            }
          Text(category.displayName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.primary)
        }
        .shadow(color: .white.opacity(0.75), radius: 2)
      }
    }
  }
}

private struct MapLocationActionBar: View {
  let image: GalleryImage
  let userCoordinate: CLLocationCoordinate2D?

  var body: some View {
    HStack(spacing: 8) {
      MapTravelEstimateButton(image: image, userCoordinate: userCoordinate)
      MapNavigateButton(image: image)
    }
  }
}

private struct MapTravelEstimateButton: View {
  let image: GalleryImage
  let userCoordinate: CLLocationCoordinate2D?

  @State private var isEstimating = false
  @State private var showResultAlert = false
  @State private var estimate: MapTravelEstimate?
  @State private var errorMessage: String?

  var body: some View {
    Button(action: performEstimate) {
      Group {
        if isEstimating {
          ProgressView()
            .tint(.white)
        } else {
          Label("当前估算", systemImage: "clock.arrow.circlepath")
            .font(.caption.weight(.semibold))
        }
      }
      .foregroundStyle(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color(red: 0.18, green: 0.62, blue: 0.52), in: Capsule())
      .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
    }
    .buttonStyle(.plain)
    .disabled(isEstimating)
    .alert(alertTitle, isPresented: $showResultAlert) {
      Button("确定", role: .cancel) {}
    } message: {
      Text(alertMessage)
    }
  }

  private var alertTitle: String {
    estimate == nil ? "无法估算" : "路程估算"
  }

  private var alertMessage: String {
    if let errorMessage {
      return errorMessage
    }
    guard let estimate else {
      return "请稍后再试。"
    }
    let method = estimate.usesRouteEstimate ? "驾车路线" : "直线距离折算"
    return """
    \(image.locationLabel)
    距离：\(estimate.distanceText)
    预计用时：\(estimate.durationText)
    估算方式：\(method)
    """
  }

  private func performEstimate() {
    guard let userCoordinate else {
      errorMessage = MapTravelEstimatorError.missingUserLocation.errorDescription
      estimate = nil
      showResultAlert = true
      return
    }

    isEstimating = true
    errorMessage = nil
    estimate = nil

    Task {
      do {
        let result = try await MapTravelEstimator.estimate(
          from: userCoordinate,
          to: image
        )
        await MainActor.run {
          estimate = result
          showResultAlert = true
          isEstimating = false
        }
      } catch let error as MapTravelEstimatorError {
        await MainActor.run {
          errorMessage = error.errorDescription
          showResultAlert = true
          isEstimating = false
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
          showResultAlert = true
          isEstimating = false
        }
      }
    }
  }
}

private struct MapNavigateButton: View {
  let image: GalleryImage

  @AppStorage(AppSettings.preferredMapAppKey) private var mapAppRaw = PreferredMapApp.apple.rawValue
  @State private var showMapOptions = false

  private var orderedOptions: [PreferredMapApp] {
    let preferred = PreferredMapApp(rawValue: mapAppRaw) ?? .apple
    return PreferredMapApp.options(preferred: preferred)
  }

  var body: some View {
    Button {
      showMapOptions = true
    } label: {
      Label("导航到位置", systemImage: "location.north.line.fill")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 0.22, green: 0.48, blue: 0.95), in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
    }
    .buttonStyle(.plain)
    .confirmationDialog("选择地图应用", isPresented: $showMapOptions, titleVisibility: .visible) {
      ForEach(orderedOptions) { mapApp in
        Button(mapApp.title) {
          MapAppLauncher.navigate(to: image, using: mapApp)
        }
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text(image.locationLabel)
    }
  }
}

private struct MapImageCalloutCard: View {
  let image: GalleryImage
  let onDismiss: () -> Void
  let onPreview: () -> Void

  @State private var showsDetail = false

  private let expandedImageHeight: CGFloat = 176
  private let compactThumbnailSize: CGFloat = 64

  var body: some View {
    Group {
      if showsDetail {
        detailLayout
      } else {
        expandedImageLayout
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    .animation(.easeInOut(duration: 0.22), value: showsDetail)
    .id(image.id)
  }

  private var expandedImageLayout: some View {
    ZStack(alignment: .topTrailing) {
      calloutImage
        .frame(maxWidth: .infinity)
        .frame(height: expandedImageHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onPreview)

      HStack(alignment: .top, spacing: 8) {
        Spacer(minLength: 0)

        VStack(spacing: 8) {
          MapCalloutIconButton(
            systemName: "xmark",
            foreground: .secondary,
            background: Color(.tertiarySystemFill),
            action: onDismiss
          )

          MapCalloutIconButton(
            systemName: "arrow.down.right.and.arrow.up.left",
            foreground: .white,
            background: image.category.pinColor,
            action: { showsDetail = true }
          )
          .accessibilityLabel("缩小并显示详情")
        }
      }
      .padding(8)
    }
  }

  private var detailLayout: some View {
    HStack(spacing: 12) {
      calloutImage
        .frame(width: compactThumbnailSize, height: compactThumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture(perform: onPreview)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Circle()
            .fill(image.category.pinColor)
            .frame(width: 8, height: 8)
          Text(image.category.displayName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(image.category.pinColor)
        }
        Text(image.title)
          .font(.subheadline.weight(.semibold))
        Text(image.description)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      Spacer(minLength: 0)

      VStack(spacing: 8) {
        MapCalloutIconButton(
          systemName: "xmark",
          foreground: .secondary,
          background: Color(.tertiarySystemFill),
          action: onDismiss
        )

        MapCalloutIconButton(
          systemName: "arrow.up.left.and.arrow.down.right",
          foreground: .white,
          background: image.category.pinColor,
          action: { showsDetail = false }
        )
        .accessibilityLabel("放大图片")
      }
    }
  }

  @ViewBuilder
  private var calloutImage: some View {
    if image.url.isFileURL {
      GalleryThumbnailImage(url: image.url)
    } else {
      AsyncImage(url: image.url) { phase in
        switch phase {
        case .success(let loaded):
          loaded.resizable().scaledToFill()
        default:
          Rectangle().fill(Color(.secondarySystemGroupedBackground))
        }
      }
    }
  }
}

private struct MapCalloutIconButton: View {
  let systemName: String
  let foreground: Color
  let background: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.caption.weight(.bold))
        .foregroundStyle(foreground)
        .frame(width: 28, height: 28)
        .background(background, in: Circle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Simple flow layout for legend chips

private struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let result = arrange(proposal: proposal, subviews: subviews)
    return result.size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let result = arrange(proposal: proposal, subviews: subviews)
    for (index, position) in result.positions.enumerated() {
      subviews[index].place(
        at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
        proposal: .unspecified
      )
    }
  }

  private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
    let maxWidth = proposal.width ?? .infinity
    var positions: [CGPoint] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var maxX: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > maxWidth, x > 0 {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      positions.append(CGPoint(x: x, y: y))
      rowHeight = max(rowHeight, size.height)
      x += size.width + spacing
      maxX = max(maxX, x - spacing)
    }

    return (CGSize(width: maxX, height: y + rowHeight), positions)
  }
}

@MainActor
final class MapLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
  @Published var userCoordinate: CLLocationCoordinate2D?

  private let manager = CLLocationManager()

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
  }

  func requestAuthorization() {
    manager.requestWhenInUseAuthorization()
    manager.startUpdatingLocation()
  }

  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    Task { @MainActor in
      if manager.authorizationStatus == .authorizedWhenInUse
        || manager.authorizationStatus == .authorizedAlways
      {
        manager.startUpdatingLocation()
      }
    }
  }

  nonisolated func locationManager(
    _ manager: CLLocationManager,
    didUpdateLocations locations: [CLLocation]
  ) {
    guard let location = locations.last else { return }
    Task { @MainActor in
      userCoordinate = location.coordinate
    }
  }
}

struct MapView_Previews: PreviewProvider {
  static var previews: some View {
    MapView()
      .environmentObject(GalleryStore.shared)
      .environmentObject(MapFocusController())
  }
}

// MARK: - Location detail map

struct MapLocationDetailView: View {
  let image: GalleryImage

  @Environment(\.dismiss) private var dismiss
  @StateObject private var locationManager = MapLocationManager()
  @State private var region: MKCoordinateRegion
  @State private var selectedMediaDestination: GalleryMediaOpenDestination?

  init(image: GalleryImage) {
    self.image = image
    _region = State(
      initialValue: MKCoordinateRegion(
        center: image.coordinate,
        span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
      )
    )
  }

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
        Map(
          coordinateRegion: $region,
          annotationItems: [image]
        ) { pin in
          MapAnnotation(coordinate: pin.coordinate) {
            ImageMapPointerPin(image: pin, isSelected: true)
          }
        }
        .ignoresSafeArea(edges: .bottom)

        VStack(spacing: 8) {
          MapImageCalloutCard(
            image: image,
            onDismiss: { dismiss() },
            onPreview: { selectedMediaDestination = .open(image, in: [image]) }
          )
          .frame(maxWidth: .infinity)

          if image.hasLocation {
            MapLocationActionBar(
              image: image,
              userCoordinate: locationManager.userCoordinate
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
      }
      .navigationTitle(image.locationLabel)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        locationManager.requestAuthorization()
      }
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
}

// MARK: - Location picker

struct MapLocationPickerView: View {
  let initialCoordinate: CLLocationCoordinate2D?
  let onConfirm: (CLLocationCoordinate2D) -> Void

  @Environment(\.dismiss) private var dismiss
  @StateObject private var locationManager = MapLocationManager()
  @State private var region: MKCoordinateRegion

  init(
    initialCoordinate: CLLocationCoordinate2D? = nil,
    onConfirm: @escaping (CLLocationCoordinate2D) -> Void
  ) {
    self.initialCoordinate = initialCoordinate
    self.onConfirm = onConfirm
    let center = initialCoordinate ?? CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
    _region = State(
      initialValue: MKCoordinateRegion(
        center: center,
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
      )
    )
  }

  private var centerCoordinate: CLLocationCoordinate2D {
    region.center
  }

  var body: some View {
    ZStack {
      Map(coordinateRegion: $region)
        .ignoresSafeArea(edges: .bottom)

      Image(systemName: "mappin.circle.fill")
        .font(.system(size: 36))
        .foregroundStyle(.red)
        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        .allowsHitTesting(false)
    }
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: 12) {
        Text(coordinateLabel)
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 12) {
          Button {
            centerOnUserLocation()
          } label: {
            Label("当前位置", systemImage: "location.fill")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)

          Button("确认选点") {
            onConfirm(centerCoordinate)
            dismiss()
          }
          .buttonStyle(.borderedProminent)
          .frame(maxWidth: .infinity)
        }
      }
      .padding(16)
      .background(.ultraThinMaterial)
    }
    .navigationTitle("选取位置")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      locationManager.requestAuthorization()
    }
    .onReceive(locationManager.$userCoordinate) { coordinate in
      guard let coordinate, initialCoordinate == nil else { return }
      region.center = coordinate
    }
  }

  private var coordinateLabel: String {
    String(
      format: "纬度 %.6f · 经度 %.6f",
      centerCoordinate.latitude,
      centerCoordinate.longitude
    )
  }

  private func centerOnUserLocation() {
    if let coordinate = locationManager.userCoordinate {
      region.center = coordinate
    } else {
      locationManager.requestAuthorization()
    }
  }
}
