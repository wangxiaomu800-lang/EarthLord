//
//  ExplorationManager.swift
//  EarthLord
//
//  探索管理器
//  负责管理探索状态、GPS追踪、距离计算、时长计时
//

import Foundation
import CoreLocation
import Combine

/// 探索管理器
@MainActor
class ExplorationManager: NSObject, ObservableObject {
    // MARK: - 单例
    static let shared = ExplorationManager()

    // MARK: - 发布属性

    /// 是否正在探索
    @Published var isExploring: Bool = false

    /// 当前累计距离（米）
    @Published var currentDistance: Double = 0

    /// 当前探索时长（秒）
    @Published var currentDuration: TimeInterval = 0

    /// 探索轨迹点
    @Published var explorationPath: [CLLocationCoordinate2D] = []

    // MARK: - 私有属性

    /// 位置管理器
    private let locationManager = CLLocationManager()

    /// 上一个有效位置点
    private var lastValidLocation: CLLocation?

    /// 探索开始时间
    private var startTime: Date?

    /// 探索开始位置
    private var startLocation: CLLocationCoordinate2D?

    /// 计时器
    private var durationTimer: Timer?

    /// 上次位置更新时间
    private var lastLocationUpdateTime: Date?

    // MARK: - 常量

    /// GPS 精度阈值（米）- 精度差于此值的点将被忽略
    private let accuracyThreshold: Double = 50.0

    /// 单次距离跳变阈值（米）- 与上一点距离超过此值的点将被忽略
    private let distanceJumpThreshold: Double = 100.0

    /// 最小时间间隔（秒）- 距离上次更新小于此时间的点将被忽略
    private let minimumTimeInterval: TimeInterval = 1.0

    // MARK: - 初始化

    private override init() {
        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // 移动5米更新一次（更频繁的更新以获得更准确的轨迹）
        locationManager.allowsBackgroundLocationUpdates = false
    }

    // MARK: - 公开方法

    /// 开始探索
    func startExploration() {
        print("🔍 开始探索")

        // 重置状态
        isExploring = true
        currentDistance = 0
        currentDuration = 0
        explorationPath = []
        lastValidLocation = nil
        startTime = Date()
        lastLocationUpdateTime = nil

        // 记录开始位置
        if let location = LocationManager.shared.userLocation {
            startLocation = location
            explorationPath.append(location)
            print("📍 探索起点: \(location.latitude), \(location.longitude)")
        }

        // 开始GPS追踪
        locationManager.startUpdatingLocation()

        // 启动计时器（每秒更新一次时长）
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if let startTime = self.startTime {
                    self.currentDuration = Date().timeIntervalSince(startTime)
                }
            }
        }

        print("✅ 探索已开始")
    }

    /// 停止探索
    /// - Returns: 探索结果数据（距离、时长、起始位置等）
    func stopExploration() -> (distance: Double, duration: TimeInterval, startLocation: CLLocationCoordinate2D?, endLocation: CLLocationCoordinate2D?) {
        print("🛑 停止探索")

        // 停止GPS追踪
        locationManager.stopUpdatingLocation()

        // 停止计时器
        durationTimer?.invalidate()
        durationTimer = nil

        // 计算最终时长
        if let startTime = startTime {
            currentDuration = Date().timeIntervalSince(startTime)
        }

        // 获取结束位置
        let endLocation = explorationPath.last

        // 保存结果
        let finalDistance = currentDistance
        let finalDuration = currentDuration
        let finalStartLocation = startLocation
        let finalEndLocation = endLocation

        // 重置状态
        isExploring = false

        print("📊 探索统计:")
        print("   - 距离: \(finalDistance) 米")
        print("   - 时长: \(Int(finalDuration)) 秒")
        print("   - 轨迹点: \(explorationPath.count) 个")

        return (finalDistance, finalDuration, finalStartLocation, finalEndLocation)
    }

    // MARK: - 私有方法

    /// 处理新的位置更新
    private func handleLocationUpdate(_ location: CLLocation) {
        guard isExploring else { return }

        // 1. 检查精度
        if location.horizontalAccuracy > accuracyThreshold {
            print("⚠️ GPS精度太差: \(location.horizontalAccuracy)m，忽略此点")
            return
        }

        // 2. 检查时间间隔
        if let lastTime = lastLocationUpdateTime {
            let timeInterval = location.timestamp.timeIntervalSince(lastTime)
            if timeInterval < minimumTimeInterval {
                print("⚠️ 时间间隔太短: \(timeInterval)s，忽略此点")
                return
            }
        }

        // 3. 检查距离跳变
        if let lastLocation = lastValidLocation {
            let distance = location.distance(from: lastLocation)

            if distance > distanceJumpThreshold {
                print("⚠️ 距离跳变过大: \(distance)m，忽略此点")
                return
            }

            // 累加距离
            currentDistance += distance
            print("📏 新增距离: \(String(format: "%.1f", distance))m, 总距离: \(String(format: "%.1f", currentDistance))m")
        }

        // 4. 保存为有效点
        lastValidLocation = location
        lastLocationUpdateTime = location.timestamp
        explorationPath.append(location.coordinate)

        print("✅ 有效GPS点: \(location.coordinate.latitude), \(location.coordinate.longitude), 精度: \(location.horizontalAccuracy)m")
    }
}

// MARK: - CLLocationManagerDelegate

extension ExplorationManager: CLLocationManagerDelegate {
    /// 位置更新回调
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            handleLocationUpdate(location)
        }
    }

    /// 位置更新失败回调
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ GPS定位失败: \(error.localizedDescription)")
    }
}
