//
//  TerritoryMapView.swift
//  EarthLord
//
//  Created on 2026-01-22.
//

import SwiftUI
import MapKit

/// 领地地图视图组件（显示领地边界和建筑标注）
struct TerritoryMapView: UIViewRepresentable {
    let territoryCoordinates: [CLLocationCoordinate2D]
    let buildings: [PlayerBuilding]
    let templates: [String: BuildingTemplate]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsUserLocation = true

        // 设置地图区域
        if let region = calculateRegion() {
            mapView.setRegion(region, animated: false)
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新领地多边形
        updateTerritoryPolygon(mapView)

        // 更新建筑标注
        updateBuildingAnnotations(mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Helper Methods

    /// 计算地图显示区域
    private func calculateRegion() -> MKCoordinateRegion? {
        guard !territoryCoordinates.isEmpty else { return nil }

        var minLat = territoryCoordinates[0].latitude
        var maxLat = territoryCoordinates[0].latitude
        var minLon = territoryCoordinates[0].longitude
        var maxLon = territoryCoordinates[0].longitude

        for coordinate in territoryCoordinates {
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
            latitudeDelta: (maxLat - minLat) * 1.5,
            longitudeDelta: (maxLon - minLon) * 1.5
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    /// 更新领地多边形
    private func updateTerritoryPolygon(_ mapView: MKMapView) {
        // 移除旧的多边形
        let oldOverlays = mapView.overlays.compactMap { $0 as? MKPolygon }
        mapView.removeOverlays(oldOverlays)

        // 添加新的多边形
        guard territoryCoordinates.count >= 3 else { return }

        let polygon = MKPolygon(coordinates: territoryCoordinates, count: territoryCoordinates.count)
        mapView.addOverlay(polygon)
    }

    /// 更新建筑标注
    private func updateBuildingAnnotations(_ mapView: MKMapView) {
        // 移除旧的建筑标注
        let oldAnnotations = mapView.annotations.compactMap { $0 as? BuildingAnnotation }
        mapView.removeAnnotations(oldAnnotations)

        // 添加新的建筑标注
        for building in buildings {
            guard let coord = building.coordinate else { continue }

            // ⚠️ 重要：数据库中保存的已经是 GCJ-02 坐标，直接使用无需转换
            let template = templates[building.templateId]
            let annotation = BuildingAnnotation(
                building: building,
                coordinate: coord,
                template: template
            )
            mapView.addAnnotation(annotation)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TerritoryMapView

        init(_ parent: TerritoryMapView) {
            self.parent = parent
        }

        /// 渲染多边形
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        /// 渲染建筑标注
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 排除用户位置标注
            if annotation is MKUserLocation {
                return nil
            }

            if let buildingAnnotation = annotation as? BuildingAnnotation {
                let identifier = "BuildingAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if view == nil {
                    view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                }

                view?.annotation = annotation
                view?.markerTintColor = buildingAnnotation.building.status == .active ? .systemGreen : .systemOrange
                view?.glyphImage = UIImage(systemName: buildingAnnotation.template?.category.icon ?? "building.2.fill")
                view?.canShowCallout = true

                return view
            }

            return nil
        }
    }
}

// MARK: - Building Annotation

/// 建筑标注
class BuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    let template: BuildingTemplate?
    @objc dynamic var coordinate: CLLocationCoordinate2D

    var title: String? {
        return building.buildingName
    }

    var subtitle: String? {
        return "Lv.\(building.level) - \(building.status.displayName)"
    }

    init(building: PlayerBuilding, coordinate: CLLocationCoordinate2D, template: BuildingTemplate?) {
        self.building = building
        self.coordinate = coordinate
        self.template = template
    }
}
