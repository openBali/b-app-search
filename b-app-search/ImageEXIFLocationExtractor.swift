//
//  ImageEXIFLocationExtractor.swift
//  b-app-search
//

import CoreLocation
import ImageIO

enum ImageEXIFLocationExtractor {
  /// 从图片二进制数据中读取 EXIF GPS 坐标；无坐标时返回 nil。
  static func coordinate(from data: Data) -> CLLocationCoordinate2D? {
    guard
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
      let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any]
    else { return nil }

    guard
      let latitude = doubleValue(from: gps[kCGImagePropertyGPSLatitude as String]),
      let longitude = doubleValue(from: gps[kCGImagePropertyGPSLongitude as String])
    else { return nil }

    let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String
    let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String

    var signedLatitude = latitude
    var signedLongitude = longitude
    if latRef == "S" { signedLatitude = -abs(signedLatitude) }
    if lonRef == "W" { signedLongitude = -abs(signedLongitude) }

    guard CLLocationCoordinate2DIsValid(
      CLLocationCoordinate2D(latitude: signedLatitude, longitude: signedLongitude)
    ) else { return nil }

    return CLLocationCoordinate2D(latitude: signedLatitude, longitude: signedLongitude)
  }

  private static func doubleValue(from value: Any?) -> Double? {
    switch value {
    case let number as NSNumber:
      return number.doubleValue
    case let string as String:
      return Double(string)
    default:
      return nil
    }
  }
}
