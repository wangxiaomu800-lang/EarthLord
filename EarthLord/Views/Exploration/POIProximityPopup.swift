//
//  POIProximityPopup.swift
//  EarthLord
//
//  POI 接近提示弹窗
//  当玩家进入 POI 50m 范围内时显示
//

import SwiftUI
import CoreLocation

struct POIProximityPopup: View {
    // MARK: - 参数
    let poi: POI
    let onScavenge: () -> Void
    let onDismiss: () -> Void

    // MARK: - 状态
    @State private var distance: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // 标题区域
            VStack(spacing: 8) {
                // 图标
                Text(poi.type.emoji)
                    .font(.system(size: 48))
                    .padding(.top, 24)

                // 标题
                Text("发现可搜刮地点")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // POI 名称
                Text(poi.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // 距离
                if distance > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text("距离: \(formatDistance(distance))")
                            .font(.subheadline)
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .padding(.bottom, 24)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 按钮区域
            HStack(spacing: 16) {
                // 稍后再说
                Button(action: {
                    onDismiss()
                }) {
                    Text("稍后再说")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                }

                // 立即搜刮
                Button(action: {
                    onScavenge()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bag.fill")
                            .font(.body)
                        Text("立即搜刮")
                            .font(.body)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(ApocalypseTheme.background)
        .onAppear {
            calculateDistance()
        }
    }

    // MARK: - 辅助方法

    /// 计算用户到 POI 的距离
    private func calculateDistance() {
        guard let userLocation = LocationManager.shared.userLocation else {
            return
        }

        let userCLLocation = CLLocation(
            latitude: userLocation.latitude,
            longitude: userLocation.longitude
        )
        let poiCLLocation = CLLocation(
            latitude: poi.coordinate.latitude,
            longitude: poi.coordinate.longitude
        )

        distance = userCLLocation.distance(from: poiCLLocation)
    }

    /// 格式化距离显示
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f 公里", meters / 1000)
        } else {
            return String(format: "%.0f 米", meters)
        }
    }
}

// MARK: - POIType Extension

extension POIType {
    /// 获取 POI 类型对应的 emoji 图标
    var emoji: String {
        switch self {
        case .supermarket: return "🏪"
        case .hospital: return "🏥"
        case .gasStation: return "⛽"
        case .pharmacy: return "💊"
        case .factory: return "🏭"
        }
    }
}

// MARK: - Preview

#Preview {
    let samplePOI = POI(
        id: "preview_1",
        type: .supermarket,
        name: "沃尔玛超市",
        coordinate: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
        status: .discovered,
        lootItems: [],
        description: "一家废弃的超市"
    )

    POIProximityPopup(
        poi: samplePOI,
        onScavenge: {
            print("搜刮")
        },
        onDismiss: {
            print("关闭")
        }
    )
}
