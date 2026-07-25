//
//  MapAppLauncher.swift
//  b-app-search
//

import CoreLocation
import MapKit
import UIKit

enum MapAppLauncher {
  static func orderedOptions() -> [PreferredMapApp] {
    PreferredMapApp.options(preferred: AppSettings.preferredMapApp)
  }

  static func navigate(to image: GalleryImage, using mapApp: PreferredMapApp) {
    guard image.hasLocation else { return }
    let name = resolvedPlaceName(for: image)
    navigate(
      to: image.coordinate,
      name: name,
      using: mapApp
    )
  }

  static func navigate(
    to coordinate: CLLocationCoordinate2D,
    name: String,
    using mapApp: PreferredMapApp
  ) {
    switch mapApp {
    case .apple:
      openAppleMaps(coordinate: coordinate, name: name)
    case .google:
      openGoogleMaps(coordinate: coordinate, name: name)
    case .amap:
      openAmap(coordinate: coordinate, name: name)
    }
  }

  private static func resolvedPlaceName(for image: GalleryImage) -> String {
    if let locationName = image.locationName?.trimmingCharacters(in: .whitespacesAndNewlines),
       !locationName.isEmpty
    {
      return locationName
    }
    return image.title
  }

  private static func openAppleMaps(coordinate: CLLocationCoordinate2D, name: String) {
    let placemark = MKPlacemark(coordinate: coordinate)
    let item = MKMapItem(placemark: placemark)
    item.name = name
    item.openInMaps(launchOptions: [
      MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
    ])
  }

  private static func openGoogleMaps(coordinate: CLLocationCoordinate2D, name: String) {
    let lat = coordinate.latitude
    let lon = coordinate.longitude
    let appURL = URL(string: "comgooglemaps://?daddr=\(lat),\(lon)&directionsmode=driving")
    let webURL = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lon)&travelmode=driving")

    open(appURL: appURL, webURL: webURL)
  }

  private static func openAmap(coordinate: CLLocationCoordinate2D, name: String) {
    let lat = coordinate.latitude
    let lon = coordinate.longitude
    let encodedName = percentEncoded(name)
    let appURL = URL(
      string: "iosamap://path?sourceApplication=b-app-search&dlat=\(lat)&dlon=\(lon)&dname=\(encodedName)&dev=0&t=0"
    )
    let webURL = URL(string: "https://uri.amap.com/navigation?to=\(lon),\(lat),\(encodedName)&mode=car")

    open(appURL: appURL, webURL: webURL)
  }

  private static func open(appURL: URL?, webURL: URL?) {
    if let appURL, UIApplication.shared.canOpenURL(appURL) {
      UIApplication.shared.open(appURL)
      return
    }
    if let webURL {
      UIApplication.shared.open(webURL)
    }
  }

  private static func percentEncoded(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
  }
}
