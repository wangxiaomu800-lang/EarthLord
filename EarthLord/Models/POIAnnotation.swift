//
//  POIAnnotation.swift
//  EarthLord
//
//  POI 地图注解类
//  用于在地图上显示 POI 标记
//

import Foundation
import MapKit

/// POI 地图注解
class POIAnnotation: NSObject, MKAnnotation {
    // MARK: - MKAnnotation 必需属性

    /// 注解坐标
    @objc dynamic var coordinate: CLLocationCoordinate2D

    /// 标题（POI 名称）
    var title: String?

    /// 副标题（POI 类型）
    var subtitle: String?

    // MARK: - 自定义属性

    /// POI 数据
    let poi: POI

    /// 是否已搜刮
    var isScavenged: Bool

    // MARK: - 初始化

    init(poi: POI, isScavenged: Bool = false) {
        self.poi = poi
        self.coordinate = poi.coordinate
        self.title = poi.name
        self.subtitle = poi.type.displayName
        self.isScavenged = isScavenged
        super.init()
    }
}
