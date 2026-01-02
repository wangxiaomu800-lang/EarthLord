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

    // MARK: - 私有属性

    /// CoreLocation 管理器
    private let locationManager = CLLocationManager()

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
