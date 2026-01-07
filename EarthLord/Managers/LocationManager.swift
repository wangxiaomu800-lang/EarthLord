//
//  LocationManager.swift
//  EarthLord
//
//  GPS 定位管理器
//  负责请求定位权限、获取用户位置、处理定位错误
//

import Foundation
import CoreLocation
import Combine

/// GPS 定位管理器
@MainActor
class LocationManager: NSObject, ObservableObject {
    // MARK: - 单例
    static let shared = LocationManager()

    // MARK: - 发布属性

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// 定位错误信息
    @Published var locationError: String?

    // MARK: - 路径追踪属性

    /// 是否正在追踪路径
    @Published var isTracking: Bool = false

    /// 路径坐标数组（存储 WGS-84 原始坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否闭合
    @Published var isPathClosed: Bool = false

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    /// 领地数量
    @Published var territoryCount: Int = 0

    // MARK: - 验证状态属性

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算出的领地面积（平方米）
    @Published var calculatedArea: Double = 0

    /// 是否应该显示验证横幅（用于触发UI显示）
    @Published var shouldShowValidationBanner: Bool = false

    // MARK: - 私有属性

    /// CoreLocation 管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（用于 Timer 采点）
    private var currentLocation: CLLocation?

    /// 路径采点定时器
    private var pathUpdateTimer: Timer?

    // MARK: - 验证常量

    /// 闭环距离阈值（米）
    private let closureDistanceThreshold: Double = 30.0

    /// 最少路径点数
    private let minimumPathPoints: Int = 10

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

    // MARK: - 初始化

    private override init() {
        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // 最高精度
        locationManager.distanceFilter = 10 // 移动10米才更新位置

        // 获取当前授权状态
        authorizationStatus = locationManager.authorizationStatus

        // 加载领地数量
        territoryCount = UserDefaults.standard.integer(forKey: "territoryCount")

        print("📍 LocationManager 已初始化，当前领地数: \(territoryCount)")
    }

    // MARK: - 公开方法

    /// 请求定位权限
    func requestPermission() {
        print("📍 请求定位权限...")
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始定位
    func startUpdatingLocation() {
        guard isAuthorized else {
            print("⚠️ 未授权，无法开始定位")
            locationError = "请先授权定位权限"
            return
        }

        print("📍 开始定位...")
        locationManager.startUpdatingLocation()
    }

    /// 停止定位
    func stopUpdatingLocation() {
        print("📍 停止定位")
        locationManager.stopUpdatingLocation()
    }

    // MARK: - 路径追踪方法

    /// 开始路径追踪
    func startPathTracking() {
        guard isAuthorized else {
            print("⚠️ 未授权，无法开始路径追踪")
            return
        }

        // 清除旧路径
        pathCoordinates.removeAll()
        pathUpdateVersion = 0
        isPathClosed = false

        // 标记为追踪中
        isTracking = true

        // 启动定时器（每2秒检查一次）
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.recordPathPoint()
            }
        }

        print("🚩 开始路径追踪")
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)
    }

    /// 停止路径追踪
    func stopPathTracking() {
        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 标记为停止追踪
        isTracking = false

        // 如果已闭环，提示用户
        if isPathClosed {
            print("🛑 停止路径追踪，共记录 \(pathCoordinates.count) 个点（已闭环）")
            TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点（已闭环）", type: .info)
        } else {
            print("🛑 停止路径追踪，共记录 \(pathCoordinates.count) 个点（未闭环）")
            TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点（未闭环）", type: .info)

            // 如果有一些点但未闭环，检查原因并提示
            if pathCoordinates.count > 0 {
                // 检查点数
                if pathCoordinates.count < minimumPathPoints {
                    let errorMsg = "点数不足: \(pathCoordinates.count)个 (需≥\(minimumPathPoints)个)"
                    TerritoryLogger.shared.log(errorMsg, type: .error)
                    territoryValidationPassed = false
                    territoryValidationError = errorMsg
                    calculatedArea = 0
                    shouldShowValidationBanner = true
                } else {
                    // 点数够了但未闭环，检查距离起点
                    if let startCoordinate = pathCoordinates.first,
                       let currentCoordinate = pathCoordinates.last {
                        let startLocation = CLLocation(latitude: startCoordinate.latitude, longitude: startCoordinate.longitude)
                        let currentLocation = CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
                        let distance = currentLocation.distance(from: startLocation)

                        let errorMsg = "未闭环: 距起点 \(String(format: "%.1f", distance))m (需≤\(String(format: "%.0f", closureDistanceThreshold))m)"
                        TerritoryLogger.shared.log(errorMsg, type: .error)
                        territoryValidationPassed = false
                        territoryValidationError = errorMsg
                        calculatedArea = 0
                        shouldShowValidationBanner = true
                    }
                }
            }
        }

        // ⚠️ 重要：清空路径和重置所有验证状态，防止重复上传
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
    }

    /// 清除路径
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion = 0
        isPathClosed = false

        print("🗑️ 已清除路径")
    }

    /// 记录路径点（定时器回调）
    private func recordPathPoint() {
        guard isTracking else { return }
        guard let location = currentLocation else {
            print("⚠️ 当前位置为空，跳过记录")
            return
        }

        // 速度检测：超速则不记录
        if !validateMovementSpeed(newLocation: location) {
            print("⚠️ 速度超标，跳过记录")
            return
        }

        // 判断是否需要记录新点
        if let lastCoordinate = pathCoordinates.last {
            // 计算距离上个点的距离
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let distance = location.distance(from: lastLocation)

            // 距离小于 10 米，不记录
            if distance < 10 {
                print("📍 距离太近(\(String(format: "%.1f", distance))m)，跳过记录")
                return
            }
        }

        // 记录新点（存储 WGS-84 原始坐标）
        pathCoordinates.append(location.coordinate)
        pathUpdateVersion += 1

        let count = pathCoordinates.count
        print("✅ 记录路径点: 纬度 \(location.coordinate.latitude), 经度 \(location.coordinate.longitude) (共 \(count) 点)")

        // 计算距离上个点的距离（用于日志）
        var distanceText = ""
        if count > 1 {
            let lastCoordinate = pathCoordinates[count - 2]
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let distance = location.distance(from: lastLocation)
            distanceText = "，距上点 \(String(format: "%.1f", distance))m"
        }

        TerritoryLogger.shared.log("记录第 \(count) 个点\(distanceText)", type: .info)

        // 检查是否形成闭环
        checkPathClosure()
    }

    /// 验证移动速度
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常，false 表示超速
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 使用 CLLocation 自带的 speed 属性（单位：米/秒）
        // speed < 0 表示速度无效
        guard newLocation.speed >= 0 else {
            print("📍 GPS 速度数据无效，跳过检测")
            return true
        }

        // 转换为 km/h
        let speedKmh = newLocation.speed * 3.6

        print("📍 当前速度: \(String(format: "%.1f", speedKmh)) km/h")

        // 速度检测（按需求文档设置阈值）
        if speedKmh > 30 {
            // 严重超速：停止追踪（30 km/h 以上自动停止）
            speedWarning = "速度过快 (\(String(format: "%.1f", speedKmh)) km/h)，已暂停追踪"
            isOverSpeed = true
            TerritoryLogger.shared.log("超速 \(String(format: "%.1f", speedKmh)) km/h，已停止追踪", type: .error)
            stopPathTracking()
            print("❌ 严重超速 (\(String(format: "%.1f", speedKmh)) km/h)，已停止追踪")
            return false
        } else if speedKmh > 15 {
            // 轻微超速：警告但继续追踪（15 km/h 以上显示警告）
            speedWarning = "速度较快 (\(String(format: "%.1f", speedKmh)) km/h)，请步行圈地"
            isOverSpeed = true
            TerritoryLogger.shared.log("速度较快 \(String(format: "%.1f", speedKmh)) km/h", type: .warning)
            print("⚠️ 速度超标 (\(String(format: "%.1f", speedKmh)) km/h)")
            return true
        } else {
            // 速度正常
            speedWarning = nil
            isOverSpeed = false
            return true
        }
    }

    /// 检查路径是否闭合
    private func checkPathClosure() {
        // 已经闭合，跳过
        guard !isPathClosed else { return }

        // 点数不足，跳过
        guard pathCoordinates.count >= minimumPathPoints else {
            print("🔍 闭环检测：点数不足（\(pathCoordinates.count)/\(minimumPathPoints)）")
            TerritoryLogger.shared.log("闭环检测：点数不足 \(pathCoordinates.count)/\(minimumPathPoints)", type: .info)
            return
        }

        // 获取起点和当前点
        guard let startCoordinate = pathCoordinates.first,
              let currentCoordinate = pathCoordinates.last else {
            return
        }

        // 计算距离起点的距离
        let startLocation = CLLocation(latitude: startCoordinate.latitude, longitude: startCoordinate.longitude)
        let currentLocation = CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
        let distance = currentLocation.distance(from: startLocation)

        // 判断是否闭合
        if distance <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1

            print("🎉 闭环检测成功！距离起点 \(String(format: "%.1f", distance)) 米")
            TerritoryLogger.shared.log("✅ 闭环成功！距起点 \(String(format: "%.1f", distance))m", type: .success)

            // 闭环成功后立即进行综合验证
            let validationResult = validateTerritory()
            if validationResult.isValid {
                // 验证通过，增加领地数量
                territoryCount += 1
                UserDefaults.standard.set(territoryCount, forKey: "territoryCount")
                print("🏆 恭喜！你已圈地 \(territoryCount) 块")
            } else {
                print("❌ 验证失败：\(validationResult.errorMessage ?? "未知错误")")
            }

            // 触发显示验证结果横幅
            shouldShowValidationBanner = true
        } else {
            print("🔍 闭环检测：距离起点 \(String(format: "%.1f", distance)) 米（需要 ≤\(closureDistanceThreshold) 米）")
            TerritoryLogger.shared.log("闭环检测：距起点 \(String(format: "%.1f", distance))m", type: .info)
        }
    }

    // MARK: - 距离与面积计算

    /// 计算路径总距离
    /// - Returns: 总距离（米）
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<(pathCoordinates.count - 1) {
            let current = pathCoordinates[i]
            let next = pathCoordinates[i + 1]

            let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
            let nextLocation = CLLocation(latitude: next.latitude, longitude: next.longitude)

            totalDistance += currentLocation.distance(from: nextLocation)
        }

        return totalDistance
    }

    /// 计算多边形面积（使用鞋带公式，考虑地球曲率）
    /// - Returns: 面积（平方米）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        let earthRadius: Double = 6371000 // 地球半径（米）
        var area: Double = 0

        for i in 0..<pathCoordinates.count {
            let current = pathCoordinates[i]
            let next = pathCoordinates[(i + 1) % pathCoordinates.count] // 循环取点

            // 经纬度转弧度
            let lat1 = current.latitude * .pi / 180
            let lon1 = current.longitude * .pi / 180
            let lat2 = next.latitude * .pi / 180
            let lon2 = next.longitude * .pi / 180

            // 鞋带公式（球面修正）
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * earthRadius * earthRadius / 2.0)
        return area
    }

    // MARK: - 自相交检测

    /// 判断两条线段是否相交（使用 CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1的起点
    ///   - p2: 线段1的终点
    ///   - p3: 线段2的起点
    ///   - p4: 线段2的终点
    /// - Returns: true 表示相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                   p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        /// CCW 辅助函数：判断三点是否逆时针排列
        /// - Parameters:
        ///   - a: 第一个点
        ///   - b: 第二个点
        ///   - c: 第三个点
        /// - Returns: 叉积 > 0 则为逆时针
        func ccw(a: CLLocationCoordinate2D, b: CLLocationCoordinate2D, c: CLLocationCoordinate2D) -> Bool {
            // ⚠️ 坐标映射：longitude = X轴，latitude = Y轴
            let crossProduct = (c.latitude - a.latitude) * (b.longitude - a.longitude) -
                             (b.latitude - a.latitude) * (c.longitude - a.longitude)
            return crossProduct > 0
        }

        // 判断两线段是否相交
        let ccw1 = ccw(a: p1, b: p3, c: p4)
        let ccw2 = ccw(a: p2, b: p3, c: p4)
        let ccw3 = ccw(a: p1, b: p2, c: p3)
        let ccw4 = ccw(a: p1, b: p2, c: p4)

        return (ccw1 != ccw2) && (ccw3 != ccw4)
    }

    /// 检测路径是否自相交
    /// - Returns: true 表示有自交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量（增加到3，减少误判）
        let skipHeadCount = 3
        let skipTailCount = 3

        for i in 0..<segmentCount {
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 跳过首尾附近线段的比较
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount

                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                // ✅ 只检查距离较远的线段，避免GPS误差导致的误判
                // 计算线段i的中点到线段j的中点的距离
                let mid1 = CLLocation(latitude: (p1.latitude + p2.latitude) / 2,
                                     longitude: (p1.longitude + p2.longitude) / 2)
                let mid2 = CLLocation(latitude: (p3.latitude + p4.latitude) / 2,
                                     longitude: (p3.longitude + p4.longitude) / 2)
                let midDistance = mid1.distance(from: mid2)

                // 如果两线段中点距离太近（<20米），可能是GPS误差，跳过
                if midDistance < 20 {
                    continue
                }

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交（中点距离\(String(format: "%.1f", midDistance))m）", type: .error)
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        return false
    }

    // MARK: - 综合验证

    /// 综合验证领地是否有效
    /// - Returns: (是否有效, 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            let errorMsg = "点数不足: \(pointCount)个 (需≥\(minimumPathPoints)个)"
            TerritoryLogger.shared.log(errorMsg, type: .error)
            territoryValidationPassed = false
            territoryValidationError = errorMsg
            calculatedArea = 0
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("点数检查: \(pointCount)个点 ✓", type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let errorMsg = "距离不足: \(String(format: "%.0f", totalDistance))m (需≥\(String(format: "%.0f", minimumTotalDistance))m)"
            TerritoryLogger.shared.log(errorMsg, type: .error)
            territoryValidationPassed = false
            territoryValidationError = errorMsg
            calculatedArea = 0
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✓", type: .info)

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let errorMsg = "轨迹自相交，请勿画8字形"
            territoryValidationPassed = false
            territoryValidationError = errorMsg
            calculatedArea = 0
            return (false, errorMsg)
        }

        // 4. 面积检查
        let area = calculatePolygonArea()
        calculatedArea = area
        if area < minimumEnclosedArea {
            let errorMsg = "面积不足: \(String(format: "%.0f", area))m² (需≥\(String(format: "%.0f", minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log(errorMsg, type: .error)
            territoryValidationPassed = false
            territoryValidationError = errorMsg
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✓", type: .info)

        // 所有验证通过
        let successMsg = "领地验证通过！面积: \(String(format: "%.0f", area))m²"
        TerritoryLogger.shared.log(successMsg, type: .success)
        territoryValidationPassed = true
        territoryValidationError = nil
        return (true, nil)
    }

    // MARK: - 计算属性

    /// 是否已授权
    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    /// 是否被拒绝
    var isDenied: Bool {
        authorizationStatus == .denied
    }

    /// 是否是首次请求
    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    /// 授权状态变化时调用
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            authorizationStatus = status

            print("📍 定位授权状态变化: \(status.rawValue)")

            // 授权成功后自动开始定位
            if isAuthorized {
                print("✅ 定位授权成功，开始定位")
                startUpdatingLocation()
            } else if isDenied {
                print("❌ 定位授权被拒绝")
                locationError = "您已拒绝定位权限，请在设置中开启"
            }
        }
    }

    /// 位置更新时调用
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }

            // 更新用户位置
            userLocation = location.coordinate

            // 更新当前位置（用于路径追踪的 Timer）
            currentLocation = location

            print("📍 位置更新: 纬度 \(location.coordinate.latitude), 经度 \(location.coordinate.longitude)")

            // 清除错误信息
            locationError = nil
        }
    }

    /// 定位失败时调用
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ 定位失败: \(error.localizedDescription)")

            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    locationError = "定位权限被拒绝"
                case .locationUnknown:
                    locationError = "无法获取位置，请稍后重试"
                case .network:
                    locationError = "网络错误，请检查网络连接"
                default:
                    locationError = "定位失败: \(error.localizedDescription)"
                }
            } else {
                locationError = error.localizedDescription
            }
        }
    }
}
