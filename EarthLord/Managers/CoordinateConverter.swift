//
//  CoordinateConverter.swift
//  EarthLord
//
//  坐标转换工具
//  解决中国 GPS 偏移问题：WGS-84 → GCJ-02
//

import CoreLocation
import Foundation

/// 坐标转换工具
/// 用于将 GPS 原始坐标（WGS-84）转换为中国地图坐标（GCJ-02）
struct CoordinateConverter {
    // MARK: - 常量

    /// 长半轴
    private static let a: Double = 6378245.0

    /// 扁率
    private static let ee: Double = 0.00669342162296594323

    /// π
    private static let pi: Double = 3.1415926535897932384626

    // MARK: - 公开方法

    /// WGS-84 坐标转换为 GCJ-02 坐标
    /// - Parameter wgs84: WGS-84 坐标（GPS 原始坐标）
    /// - Returns: GCJ-02 坐标（中国地图坐标）
    static func wgs84ToGcj02(_ wgs84: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 判断是否在中国境外
        if isOutOfChina(wgs84.latitude, wgs84.longitude) {
            return wgs84 // 境外不需要转换
        }

        var dLat = transformLat(wgs84.longitude - 105.0, wgs84.latitude - 35.0)
        var dLon = transformLon(wgs84.longitude - 105.0, wgs84.latitude - 35.0)

        let radLat = wgs84.latitude / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)

        let mgLat = wgs84.latitude + dLat
        let mgLon = wgs84.longitude + dLon

        return CLLocationCoordinate2D(latitude: mgLat, longitude: mgLon)
    }

    /// 批量转换坐标数组
    /// - Parameter wgs84Array: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func wgs84ToGcj02(_ wgs84Array: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return wgs84Array.map { wgs84ToGcj02($0) }
    }

    // MARK: - 私有方法

    /// 判断坐标是否在中国境外
    private static func isOutOfChina(_ lat: Double, _ lon: Double) -> Bool {
        // 粗略判断，不在中国经纬度范围内
        if lon < 72.004 || lon > 137.8347 {
            return true
        }
        if lat < 0.8293 || lat > 55.8271 {
            return true
        }
        return false
    }

    /// 纬度转换
    private static func transformLat(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度转换
    private static func transformLon(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
        return ret
    }
}
