//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView 的 SwiftUI 包装器
//  负责显示地图、应用末世滤镜、处理用户位置居中
//

import SwiftUI
import MapKit

/// 地图视图（SwiftUI 包装 MKMapView）
struct MapViewRepresentable: UIViewRepresentable {
    /// 用户位置（绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位（绑定）
    @Binding var hasLocatedUser: Bool

    /// 追踪路径坐标数组（绑定）
    @Binding var trackingPath: [CLLocationCoordinate2D]

    /// 路径更新版本号
    var pathUpdateVersion: Int

    /// 是否正在追踪
    var isTracking: Bool

    /// 路径是否闭合
    var isPathClosed: Bool

    // MARK: - UIViewRepresentable

    /// 创建 MKMapView
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 基础配置
        mapView.mapType = .hybrid // 卫星图+道路标签（末世风格）
        mapView.pointOfInterestFilter = .excludingAll // 隐藏所有POI（星巴克、麦当劳等）
        mapView.showsBuildings = false // 隐藏3D建筑
        mapView.showsUserLocation = true // 显示用户位置蓝点（关键！）
        mapView.isZoomEnabled = true // 允许缩放
        mapView.isScrollEnabled = true // 允许拖动
        mapView.isRotateEnabled = true // 允许旋转
        mapView.isPitchEnabled = false // 禁用3D倾斜视角

        // 注意：MKMapView 的地名标签语言由 Apple Maps 服务器控制
        // 需要通过改变整个应用的语言环境来影响地图语言
        // 这将在下面通过设置 overrideUserInterfaceStyle 的父视图来处理

        // 设置代理（关键！用于接收位置更新）
        mapView.delegate = context.coordinator

        // 应用末世滤镜
        applyApocalypseFilter(to: mapView)

        print("🗺️ 地图视图已创建")

        return mapView
    }

    /// 更新地图
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 地图更新由 Coordinator 的代理方法处理
        // 语言切换时，整个地图视图会通过 .id() 修饰符被重建，因此不需要在这里处理

        // 更新追踪路径
        updateTrackingPath(mapView: mapView, context: context)
    }

    /// 创建协调器
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 轨迹更新

    /// 更新追踪路径
    private func updateTrackingPath(mapView: MKMapView, context: Context) {
        // 检查路径版本是否变化
        if context.coordinator.lastPathVersion != pathUpdateVersion {
            context.coordinator.lastPathVersion = pathUpdateVersion

            // 移除旧的轨迹和多边形
            mapView.removeOverlays(mapView.overlays)

            // 如果有新路径，绘制新轨迹
            if trackingPath.count >= 2 {
                // ⭐ 关键：将 WGS-84 坐标转换为 GCJ-02 坐标
                // 中国区需要手动转换坐标才能准确显示
                let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(trackingPath)

                // 创建轨迹线
                let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
                mapView.addOverlay(polyline)

                print("🎨 已绘制轨迹，共 \(trackingPath.count) 个点（已转换坐标）")

                // 如果已闭环且点数足够，绘制多边形填充
                if isPathClosed && trackingPath.count >= 3 {
                    let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
                    mapView.addOverlay(polygon)
                    print("🟢 已绘制闭环多边形")
                }
            }
        }
    }

    // MARK: - 滤镜效果

    /// 应用末世滤镜（泛黄、降低饱和度）
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 色调控制：降低饱和度和亮度
        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(-0.15, forKey: kCIInputBrightnessKey) // 稍微变暗
        colorControls?.setValue(0.5, forKey: kCIInputSaturationKey) // 降低饱和度

        // 棕褐色调：废土的泛黄效果
        let sepiaFilter = CIFilter(name: "CISepiaTone")
        sepiaFilter?.setValue(0.65, forKey: kCIInputIntensityKey) // 泛黄强度

        // 应用滤镜到地图图层
        if let colorControls = colorControls, let sepiaFilter = sepiaFilter {
            mapView.layer.filters = [colorControls, sepiaFilter]
        }

        print("🎨 已应用末世滤镜")
    }

    // MARK: - Coordinator

    /// 协调器（处理 MKMapView 的代理回调）
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable

        /// 是否已完成首次居中（防止重复居中）
        private var hasInitialCentered = false

        /// 上次的路径版本号（用于检测路径变化）
        var lastPathVersion: Int = 0

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate

        /// ⭐ 关键方法：用户位置更新时调用
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置
            guard let location = userLocation.location else { return }

            // 更新绑定的位置
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            print("🗺️ 地图接收到用户位置: \(location.coordinate.latitude), \(location.coordinate.longitude)")

            // 首次获得位置时，自动居中地图
            guard !hasInitialCentered else {
                print("🗺️ 已完成首次居中，跳过")
                return
            }

            // 创建居中区域（约1公里范围）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000, // 纬度范围1公里
                longitudinalMeters: 1000  // 经度范围1公里
            )

            // 平滑居中地图
            mapView.setRegion(region, animated: true)

            print("🗺️ 地图已自动居中到用户位置")

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }
        }

        /// 地图区域变化时调用
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 用户手动拖动地图时，这里不做任何处理
            // hasInitialCentered 确保不会自动拉回
        }

        /// 地图加载完成时调用
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            print("🗺️ 地图加载完成")
        }

        /// 地图加载失败时调用
        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
            print("❌ 地图加载失败: \(error.localizedDescription)")
        }

        // MARK: - 轨迹渲染

        /// ⭐ 关键方法：渲染覆盖物（轨迹线和多边形）
        /// 如果不实现这个方法，轨迹添加了也看不见！
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 渲染轨迹线
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // 根据是否闭环设置颜色
                if parent.isPathClosed {
                    renderer.strokeColor = UIColor.systemGreen // 闭环：绿色
                } else {
                    renderer.strokeColor = UIColor.systemCyan // 未闭环：青色
                }

                renderer.lineWidth = 5 // 线宽5pt
                renderer.lineCap = .round // 圆头
                renderer.alpha = 0.8 // 透明度

                return renderer
            }

            // 渲染多边形填充
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 填充色：半透明绿色
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                // 边框色：绿色
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2

                return renderer
            }

            // 默认渲染器
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
