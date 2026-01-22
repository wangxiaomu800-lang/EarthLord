//
//  BuildingLocationPickerView.swift
//  EarthLord
//
//  Created on 2026-01-22.
//

import SwiftUI
import MapKit

/// 建筑位置选择器（地图选点）
struct BuildingLocationPickerView: View {
    let territoryCoordinates: [CLLocationCoordinate2D]
    let existingBuildings: [PlayerBuilding]
    let buildingTemplates: [String: BuildingTemplate]

    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                LocationPickerMapView(
                    territoryCoordinates: territoryCoordinates,
                    existingBuildings: existingBuildings,
                    buildingTemplates: buildingTemplates,
                    selectedCoordinate: $selectedCoordinate
                )
                .ignoresSafeArea()

                // 提示信息
                VStack {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(ApocalypseTheme.primary)
                        Text("点击领地内的位置放置建筑")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .padding()
                    .background(ApocalypseTheme.cardBackground.opacity(0.95))
                    .cornerRadius(12)
                    .padding()

                    Spacer()
                }
            }
            .navigationTitle("选择建筑位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认") {
                        onDismiss()
                    }
                    .disabled(selectedCoordinate == nil)
                }
            }
        }
    }
}

// MARK: - Location Picker Map View

struct LocationPickerMapView: UIViewRepresentable {
    let territoryCoordinates: [CLLocationCoordinate2D]
    let existingBuildings: [PlayerBuilding]
    let buildingTemplates: [String: BuildingTemplate]

    @Binding var selectedCoordinate: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard

        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        // 设置地图区域
        if let region = context.coordinator.calculateRegion() {
            mapView.setRegion(region, animated: false)
        }

        // 添加领地多边形
        if territoryCoordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: territoryCoordinates, count: territoryCoordinates.count)
            mapView.addOverlay(polygon)
        }

        // 添加已有建筑标注
        context.coordinator.addExistingBuildings(to: mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新选中位置标注
        context.coordinator.updateSelectedLocationAnnotation(mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LocationPickerMapView

        init(_ parent: LocationPickerMapView) {
            self.parent = parent
        }

        /// 计算地图显示区域
        func calculateRegion() -> MKCoordinateRegion? {
            guard !parent.territoryCoordinates.isEmpty else { return nil }

            var minLat = parent.territoryCoordinates[0].latitude
            var maxLat = parent.territoryCoordinates[0].latitude
            var minLon = parent.territoryCoordinates[0].longitude
            var maxLon = parent.territoryCoordinates[0].longitude

            for coordinate in parent.territoryCoordinates {
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

        /// 处理地图点击
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let mapView = gesture.view as! MKMapView
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // 验证点在多边形内
            if isPointInPolygon(coordinate, polygon: parent.territoryCoordinates) {
                parent.selectedCoordinate = coordinate
                print("✅ 选择位置: \(coordinate.latitude), \(coordinate.longitude)")
            } else {
                print("❌ 选择的位置不在领地范围内")
            }
        }

        /// 点在多边形内判断（射线法算法）
        private func isPointInPolygon(_ point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
            guard polygon.count >= 3 else { return false }

            var isInside = false
            var j = polygon.count - 1

            for i in 0..<polygon.count {
                let xi = polygon[i].longitude
                let yi = polygon[i].latitude
                let xj = polygon[j].longitude
                let yj = polygon[j].latitude

                if ((yi > point.latitude) != (yj > point.latitude)) &&
                   (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi) {
                    isInside = !isInside
                }
                j = i
            }

            return isInside
        }

        /// 添加已有建筑标注
        func addExistingBuildings(to mapView: MKMapView) {
            for building in parent.existingBuildings {
                guard let coord = building.coordinate else { continue }

                // ⚠️ 重要：数据库坐标已经是 GCJ-02，直接使用
                let annotation = ExistingBuildingAnnotation(
                    building: building,
                    template: parent.buildingTemplates[building.templateId]
                )
                annotation.coordinate = coord
                mapView.addAnnotation(annotation)
            }
        }

        /// 更新选中位置标注
        func updateSelectedLocationAnnotation(_ mapView: MKMapView) {
            // 移除旧的选中标注
            let oldAnnotations = mapView.annotations.compactMap { $0 as? SelectedLocationAnnotation }
            mapView.removeAnnotations(oldAnnotations)

            // 添加新的选中标注
            if let selectedCoord = parent.selectedCoordinate {
                let annotation = SelectedLocationAnnotation(coordinate: selectedCoord)
                mapView.addAnnotation(annotation)
            }
        }

        // MARK: - MKMapViewDelegate

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

        /// 渲染标注
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is SelectedLocationAnnotation {
                let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "Selected")
                view.markerTintColor = .systemBlue
                view.glyphImage = UIImage(systemName: "mappin.circle.fill")
                return view
            }

            if let buildingAnnotation = annotation as? ExistingBuildingAnnotation {
                let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "ExistingBuilding")
                view.markerTintColor = .systemGray
                view.glyphImage = UIImage(systemName: buildingAnnotation.template?.category.icon ?? "building.2.fill")
                view.canShowCallout = true
                return view
            }

            return nil
        }
    }
}

// MARK: - Annotations

/// 选中位置标注
class SelectedLocationAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D

    var title: String? {
        return "建筑位置"
    }

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

/// 已有建筑标注
class ExistingBuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    let template: BuildingTemplate?
    @objc dynamic var coordinate: CLLocationCoordinate2D

    var title: String? {
        return building.buildingName
    }

    var subtitle: String? {
        return "Lv.\(building.level)"
    }

    init(building: PlayerBuilding, template: BuildingTemplate?) {
        self.building = building
        self.coordinate = building.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        self.template = template
    }
}
