//
//  MapTravelEstimator.swift
//  b-app-search
//

import CoreLocation
import MapKit

struct MapTravelEstimate: Equatable {
  let distanceMeters: CLLocationDistance
  let travelTimeSeconds: TimeInterval
  let usesRouteEstimate: Bool

  var distanceText: String {
    if distanceMeters < 1_000 {
      return "约 \(Int(distanceMeters.rounded())) 米"
    }
    let kilometers = distanceMeters / 1_000
    if kilometers < 100 {
      return String(format: "约 %.1f 公里", kilometers)
    }
    return String(format: "约 %.0f 公里", kilometers.rounded())
  }

  var durationText: String {
    let totalMinutes = max(1, Int((travelTimeSeconds / 60).rounded()))
    if totalMinutes < 60 {
      return "约 \(totalMinutes) 分钟"
    }
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if minutes == 0 {
      return "约 \(hours) 小时"
    }
    return "约 \(hours) 小时 \(minutes) 分钟"
  }
}

enum MapTravelEstimatorError: LocalizedError {
  case missingUserLocation
  case differentCountry
  case geocodingFailed

  var errorDescription: String? {
    switch self {
    case .missingUserLocation:
      return "无法获取当前位置，请开启定位权限后重试。"
    case .differentCountry:
      return "当前位置与图片地点不在同一国家，暂不支持估算。"
    case .geocodingFailed:
      return "暂时无法判断所在国家，请稍后再试。"
    }
  }
}

enum MapTravelEstimator {
  private static let fallbackDrivingSpeedMetersPerSecond: Double = 50_000 / 3_600

  static func estimate(
    from userCoordinate: CLLocationCoordinate2D,
    to destination: GalleryImage
  ) async throws -> MapTravelEstimate {
    guard destination.hasLocation else {
      throw MapTravelEstimatorError.geocodingFailed
    }

    async let userCountry = countryCode(for: userCoordinate)
    async let destinationCountry = countryCode(for: destination.coordinate)

    let countries = try await (userCountry, destinationCountry)
    guard let userCountryCode = countries.0, let destinationCountryCode = countries.1 else {
      throw MapTravelEstimatorError.geocodingFailed
    }
    guard userCountryCode.caseInsensitiveCompare(destinationCountryCode) == .orderedSame else {
      throw MapTravelEstimatorError.differentCountry
    }

    if let routeEstimate = await routeEstimate(
      from: userCoordinate,
      to: destination.coordinate
    ) {
      return routeEstimate
    }

    return straightLineEstimate(
      from: userCoordinate,
      to: destination.coordinate
    )
  }

  private static func countryCode(for coordinate: CLLocationCoordinate2D) async throws -> String? {
    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
    return placemarks.first?.isoCountryCode
  }

  private static func routeEstimate(
    from source: CLLocationCoordinate2D,
    to destination: CLLocationCoordinate2D
  ) async -> MapTravelEstimate? {
    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
    request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
    request.transportType = .automobile

    return await withCheckedContinuation { continuation in
      MKDirections(request: request).calculate { response, _ in
        guard let route = response?.routes.first else {
          continuation.resume(returning: nil)
          return
        }
        continuation.resume(
          returning: MapTravelEstimate(
            distanceMeters: route.distance,
            travelTimeSeconds: route.expectedTravelTime,
            usesRouteEstimate: true
          )
        )
      }
    }
  }

  private static func straightLineEstimate(
    from source: CLLocationCoordinate2D,
    to destination: CLLocationCoordinate2D
  ) -> MapTravelEstimate {
    let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
    let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
    let distance = sourceLocation.distance(from: destinationLocation)
    let travelTime = distance / fallbackDrivingSpeedMetersPerSecond * 1.35

    return MapTravelEstimate(
      distanceMeters: distance,
      travelTimeSeconds: travelTime,
      usesRouteEstimate: false
    )
  }
}
