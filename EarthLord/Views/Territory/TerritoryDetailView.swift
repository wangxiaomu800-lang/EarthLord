//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情视图
//  显示领地的详细信息、地图预览、删除功能
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {
    // MARK: - 属性

    /// 领地数据
    let territory: Territory

    /// 删除回调
    let onDelete: () -> Void

    // MARK: - 状态

    /// 是否显示删除确认对话框
    @State private var showingDeleteConfirmation = false

    /// 是否正在删除
    @State private var isDeleting = false

    /// 关闭视图
    @Environment(\.dismiss) var dismiss

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 地图预览
                    mapPreview
                        .frame(height: 300)
                        .cornerRadius(12)
                        .padding(.horizontal)

                    // 详细信息
                    detailInfoSection

                    // 占位提示
                    placeholderSection

                    // 删除按钮
                    deleteButton
                }
                .padding(.top)
            }
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("确认删除", isPresented: $showingDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    Task {
                        await deleteTerritoryAction()
                    }
                }
            } message: {
                Text("确定要删除这个领地吗？此操作无法撤销。")
            }
        }
    }

    // MARK: - 子视图

    /// 地图预览
    private var mapPreview: some View {
        TerritoryMapPreview(territory: territory)
    }

    /// 详细信息区域
    private var detailInfoSection: some View {
        VStack(spacing: 16) {
            // 面积
            InfoRow(
                icon: "map.fill",
                title: "面积",
                value: territory.formattedArea,
                color: .orange
            )

            Divider()

            // 点数
            if let pointCount = territory.pointCount {
                InfoRow(
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    title: "路径点数",
                    value: "\(pointCount) 点",
                    color: .blue
                )

                Divider()
            }

            // 开始时间
            if let startedAt = territory.startedAt {
                InfoRow(
                    icon: "clock.fill",
                    title: "开始时间",
                    value: formatDate(startedAt),
                    color: .green
                )

                Divider()
            }

            // 完成时间
            if let completedAt = territory.completedAt {
                InfoRow(
                    icon: "checkmark.circle.fill",
                    title: "完成时间",
                    value: formatDate(completedAt),
                    color: .purple
                )

                Divider()
            }

            // 创建时间
            if let createdAt = territory.createdAt {
                InfoRow(
                    icon: "calendar",
                    title: "创建时间",
                    value: formatDate(createdAt),
                    color: .gray
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    /// 占位提示区域
    private var placeholderSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "ellipsis.circle")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("更多功能")
                .font(.headline)
                .foregroundColor(.primary)

            Text("重命名、建筑系统、领地交易等功能")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("敬请期待")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    /// 删除按钮
    private var deleteButton: some View {
        Button(action: {
            showingDeleteConfirmation = true
        }) {
            HStack {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "trash.fill")
                    Text("删除领地")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isDeleting)
        .padding(.horizontal)
        .padding(.bottom, 20)
    }

    // MARK: - 方法

    /// 格式化日期
    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else {
            return "未知时间"
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale.current

        return displayFormatter.string(from: date)
    }

    /// 删除领地
    private func deleteTerritoryAction() async {
        isDeleting = true
        defer { isDeleting = false }

        let success = await TerritoryManager.shared.deleteTerritory(territoryId: territory.id)

        if success {
            print("✅ 领地已删除")
            onDelete()
            dismiss()
        } else {
            print("❌ 删除领地失败")
        }
    }
}

// MARK: - 信息行组件

/// 信息行视图
private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - 地图预览组件

/// 领地地图预览
private struct TerritoryMapPreview: UIViewRepresentable {
    let territory: Territory

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.delegate = context.coordinator

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 转换坐标
        let coords = territory.toCoordinates()

        // ⚠️ 中国大陆需要坐标转换（WGS-84 → GCJ-02）
        let gcj02Coords = CoordinateConverter.wgs84ToGcj02(coords)

        guard gcj02Coords.count >= 3 else { return }

        // 移除旧的覆盖物
        mapView.removeOverlays(mapView.overlays)

        // 绘制多边形
        let polygon = MKPolygon(coordinates: gcj02Coords, count: gcj02Coords.count)
        mapView.addOverlay(polygon)

        // 设置地图区域（显示整个领地）
        let region = MKCoordinateRegion(polygon: polygon)
        mapView.setRegion(region, animated: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2.0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - MKCoordinateRegion 扩展

extension MKCoordinateRegion {
    /// 从多边形创建区域
    init(polygon: MKPolygon) {
        let coords = polygon.coordinates
        guard !coords.isEmpty else {
            self.init()
            return
        }

        var minLat = coords[0].latitude
        var maxLat = coords[0].latitude
        var minLon = coords[0].longitude
        var maxLon = coords[0].longitude

        for coord in coords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5, // 留出15%的边距
            longitudeDelta: (maxLon - minLon) * 1.5
        )

        self.init(center: center, span: span)
    }
}

// MARK: - MKPolygon 扩展

extension MKPolygon {
    /// 获取多边形的坐标数组
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

// MARK: - 预览

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "test",
            userId: "test-user",
            name: "测试领地",
            path: [
                ["lat": 39.9, "lon": 116.4],
                ["lat": 39.91, "lon": 116.4],
                ["lat": 39.91, "lon": 116.41],
                ["lat": 39.9, "lon": 116.41],
                ["lat": 39.9, "lon": 116.4]
            ],
            area: 1234.5,
            pointCount: 5,
            isActive: true,
            completedAt: "2024-01-01T12:00:00Z",
            startedAt: "2024-01-01T11:00:00Z",
            createdAt: "2024-01-01T12:00:00Z"
        ),
        onDelete: {}
    )
}
