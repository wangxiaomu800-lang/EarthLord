//
//  POISearchManager.swift
//  EarthLord
//
//  POI 搜索管理器
//  使用 MKLocalSearch 搜索附近真实地点
//

import Foundation
import MapKit
import CoreLocation

/// POI 搜索管理器
@MainActor
class POISearchManager {

    // MARK: - 公开方法

    /// 搜索附近的 POI
    /// - Parameters:
    ///   - center: 中心坐标
    ///   - radiusInMeters: 搜索半径（米），默认 1000 米
    ///   - maxResults: 最多返回的 POI 数量，默认 20（iOS 地理围栏限制）
    /// - Returns: POI 列表，按距离排序
    static func searchNearbyPOIs(
        center: CLLocationCoordinate2D,
        radiusInMeters: Double = 1000,
        maxResults: Int = 20
    ) async throws -> [POI] {
        print("\n🔍 ========== 搜索附近 POI ==========")
        print("   📍 中心坐标: (\(center.latitude), \(center.longitude))")
        print("   📏 搜索半径: \(radiusInMeters)m")
        print("   🎯 最多返回: \(maxResults) 个")

        // 定义要搜索的 POI 类型
        let searchQueries = [
            "超市",
            "医院",
            "加油站",
            "药店",
            "餐厅",
            "咖啡店"
        ]

        var allPOIs: [POI] = []
        var allMapItems: [(MKMapItem, CLLocationDistance)] = []

        // 创建搜索区域
        let regionSpan = MKCoordinateSpan(
            latitudeDelta: (radiusInMeters / 111000) * 2, // 1度约等于111km
            longitudeDelta: (radiusInMeters / 111000) * 2
        )
        let region = MKCoordinateRegion(center: center, span: regionSpan)

        print("   🔎 开始搜索 \(searchQueries.count) 种类型...")

        // 搜索每种类型
        for (index, query) in searchQueries.enumerated() {
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.region = region

                let search = MKLocalSearch(request: request)
                let response = try await search.start()

                print("      [\(index + 1)/\(searchQueries.count)] \(query): 找到 \(response.mapItems.count) 个")

                // 计算距离并添加到列表
                for mapItem in response.mapItems {
                    let itemLocation = mapItem.placemark.coordinate
                    let distance = calculateDistance(
                        from: center,
                        to: itemLocation
                    )

                    // 只保留在半径范围内的
                    if distance <= radiusInMeters {
                        allMapItems.append((mapItem, distance))
                    }
                }
            } catch {
                print("      [\(index + 1)/\(searchQueries.count)] \(query): 搜索失败 - \(error.localizedDescription)")
            }
        }

        print("   ✅ 搜索完成，共找到 \(allMapItems.count) 个地点")

        // 去重（相同名称和坐标的）
        var uniqueItems: [(MKMapItem, CLLocationDistance)] = []
        var seenLocations: Set<String> = []

        for (item, distance) in allMapItems {
            let key = "\(item.name ?? "")_\(item.placemark.coordinate.latitude)_\(item.placemark.coordinate.longitude)"
            if !seenLocations.contains(key) {
                seenLocations.insert(key)
                uniqueItems.append((item, distance))
            }
        }

        print("   🔄 去重后: \(uniqueItems.count) 个地点")

        // 按距离排序
        uniqueItems.sort { $0.1 < $1.1 }

        // 限制返回数量
        let limit = min(uniqueItems.count, maxResults)
        let selectedItems = Array(uniqueItems.prefix(limit))

        print("   📊 选取最近的 \(limit) 个地点")

        // 转换为 POI 模型
        for (index, (mapItem, distance)) in selectedItems.enumerated() {
            if let poi = convertToPOI(mapItem: mapItem, distance: distance) {
                allPOIs.append(poi)
                print("      [\(index + 1)] \(poi.name) - \(String(format: "%.0f", distance))m - \(poi.type.displayName)")
            }
        }

        print("🔍 ========== 搜索完成: \(allPOIs.count) 个 POI ==========\n")

        return allPOIs
    }

    // MARK: - 私有方法

    /// 计算两个坐标之间的距离（米）
    private static func calculateDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    /// 将 MKMapItem 转换为 POI 模型
    private static func convertToPOI(
        mapItem: MKMapItem,
        distance: CLLocationDistance
    ) -> POI? {
        guard let name = mapItem.name else {
            return nil
        }

        // 根据 POI 类别映射类型
        let poiType = mapPOIType(mapItem: mapItem)

        // 生成唯一 ID
        let id = UUID().uuidString

        // 创建 POI
        return POI(
            id: id,
            type: poiType,
            name: name,
            coordinate: mapItem.placemark.coordinate,
            status: .discovered,  // 新搜索到的 POI 都是已发现状态
            lootItems: [],  // 物品在搜刮时生成，这里先为空
            description: nil
        )
    }

    /// 映射 POI 类型
    private static func mapPOIType(mapItem: MKMapItem) -> POIType {
        // 获取 POI 类别
        let categories = mapItem.pointOfInterestCategory

        // 根据类别映射到 POIType
        if let category = categories {
            switch category {
            case .store, .foodMarket:
                return .supermarket
            case .hospital:
                return .hospital
            case .gasStation, .evCharger:
                return .gasStation
            case .pharmacy:
                return .pharmacy
            case .restaurant, .cafe, .bakery:
                return .factory  // 暂时映射到 factory，后续可以扩展 POIType
            default:
                break
            }
        }

        // 根据名称关键字匹配
        let name = mapItem.name?.lowercased() ?? ""

        if name.contains("超市") || name.contains("market") || name.contains("商店") {
            return .supermarket
        } else if name.contains("医院") || name.contains("hospital") || name.contains("诊所") {
            return .hospital
        } else if name.contains("加油") || name.contains("gas") || name.contains("油站") {
            return .gasStation
        } else if name.contains("药店") || name.contains("药房") || name.contains("pharmacy") {
            return .pharmacy
        } else if name.contains("餐厅") || name.contains("restaurant") || name.contains("咖啡") || name.contains("cafe") {
            return .factory  // 暂时映射到 factory
        }

        // 默认返回超市
        return .supermarket
    }
}
