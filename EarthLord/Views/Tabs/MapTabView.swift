//
//  MapTabView.swift
//  EarthLord
//
//  地图页面
//  显示真实地图、获取GPS定位、自动居中到用户位置
//

import SwiftUI
import MapKit

struct MapTabView: View {
    // MARK: - 状态属性

    /// 定位管理器
    @ObservedObject var locationManager = LocationManager.shared

    /// 用户位置
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否显示权限设置提示
    @State private var showSettingsAlert = false

    // MARK: - 视图主体

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background.ignoresSafeArea()

            // 地图视图
            if locationManager.isAuthorized {
                // 已授权：显示地图
                MapViewRepresentable(
                    userLocation: $userLocation,
                    hasLocatedUser: $hasLocatedUser
                )
                .ignoresSafeArea()
            } else {
                // 未授权：显示占位视图
                permissionPromptView
            }

            // 右下角：定位按钮
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    if locationManager.isAuthorized {
                        locateButton
                            .padding(.trailing, 20)
                            .padding(.bottom, 100) // 避免遮挡标签栏
                    }
                }
            }

            // 被拒绝时的提示卡片
            if locationManager.isDenied {
                deniedPermissionCard
            }
        }
        .onAppear {
            handleOnAppear()
        }
        .alert("需要定位权限", isPresented: $showSettingsAlert) {
            Button("取消", role: .cancel) { }
            Button("前往设置") {
                openSettings()
            }
        } message: {
            Text("请在设置中开启定位权限，以便在地图上显示您的位置")
        }
    }

    // MARK: - 子视图

    /// 权限请求提示视图
    private var permissionPromptView: some View {
        VStack(spacing: 24) {
            // 图标
            Image(systemName: "location.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(ApocalypseTheme.primary)

            // 标题
            Text("需要定位权限")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 说明
            Text("《地球新主》需要获取您的位置\n来显示您在末日世界中的坐标")
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // 授权按钮
            Button(action: {
                locationManager.requestPermission()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "location.fill")
                    Text("授权定位")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: 200)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [
                            ApocalypseTheme.primary,
                            ApocalypseTheme.primary.opacity(0.8)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }

    /// 被拒绝权限的提示卡片
    private var deniedPermissionCard: some View {
        VStack(spacing: 16) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.warning)

            // 标题
            Text("定位权限被拒绝")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 说明
            Text("请在设置中开启定位权限，\n以便在地图上显示您的位置")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            // 前往设置按钮
            Button(action: {
                showSettingsAlert = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                    Text("前往设置")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.primary)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding(24)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 10)
        .padding(.horizontal, 40)
    }

    /// 定位按钮
    private var locateButton: some View {
        Button(action: {
            recenterMap()
        }) {
            Image(systemName: hasLocatedUser ? "location.fill" : "location")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(ApocalypseTheme.primary)
                .cornerRadius(25)
                .shadow(color: .black.opacity(0.3), radius: 5)
        }
    }

    // MARK: - 方法

    /// 视图出现时的处理
    private func handleOnAppear() {
        print("🗺️ 地图页面已出现")

        // 如果是首次请求，请求权限
        if locationManager.isNotDetermined {
            print("🗺️ 首次请求定位权限")
            locationManager.requestPermission()
        }
        // 如果已授权，开始定位
        else if locationManager.isAuthorized {
            print("🗺️ 已授权，开始定位")
            locationManager.startUpdatingLocation()
        }
    }

    /// 重新居中地图（用户手动点击定位按钮）
    private func recenterMap() {
        guard let location = userLocation else {
            print("⚠️ 没有用户位置，无法居中")
            return
        }

        print("🗺️ 用户手动居中地图")

        // 通过更新绑定触发地图居中
        // 这里可以通过 NotificationCenter 或其他方式通知地图居中
        // 简单方式：重置 hasLocatedUser 触发重新居中
        hasLocatedUser = false

        // 延迟一帧后恢复状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            hasLocatedUser = true
        }
    }

    /// 打开系统设置
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    MapTabView()
}
