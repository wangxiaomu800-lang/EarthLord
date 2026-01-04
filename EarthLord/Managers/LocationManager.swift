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

    /// 路径是否闭合（Day16 会用）
    @Published var isPathClosed: Bool = false

    // MARK: - 私有属性

    /// CoreLocation 管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（用于 Timer 采点）
    private var currentLocation: CLLocation?

    /// 路径采点定时器
    private var pathUpdateTimer: Timer?

    // MARK: - 初始化

    private override init() {
        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // 最高精度
        locationManager.distanceFilter = 10 // 移动10米才更新位置

        // 获取当前授权状态
        authorizationStatus = locationManager.authorizationStatus

        print("📍 LocationManager 已初始化")
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
    }

    /// 停止路径追踪
    func stopPathTracking() {
        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 标记为停止追踪
        isTracking = false

        print("🛑 停止路径追踪，共记录 \(pathCoordinates.count) 个点")
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

        print("✅ 记录路径点: 纬度 \(location.coordinate.latitude), 经度 \(location.coordinate.longitude) (共 \(pathCoordinates.count) 点)")
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
