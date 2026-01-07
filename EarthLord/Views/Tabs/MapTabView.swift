//
//  MapTabView.swift
//  EarthLord
//
//  地图页面
//  显示真实地图、获取GPS定位、自动居中到用户位置
//

import SwiftUI
import MapKit
import Supabase
import Auth

struct MapTabView: View {
    // MARK: - 状态属性

    /// 定位管理器
    @ObservedObject var locationManager = LocationManager.shared

    /// 语言管理器（监听语言变化）
    @ObservedObject var languageManager = LanguageManager.shared

    /// 地图视图的唯一标识（用于强制重建地图）
    @State private var mapID = UUID()

    /// 用户位置
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否显示权限设置提示
    @State private var showSettingsAlert = false

    /// 是否显示验证结果横幅
    @State private var showValidationBanner = false

    /// 领地管理器
    @ObservedObject var territoryManager = TerritoryManager.shared

    /// 认证管理器
    @EnvironmentObject var authManager: AuthManager

    /// 已加载的领地列表
    @State private var territories: [Territory] = []

    /// 是否正在上传
    @State private var isUploading = false

    /// 上传结果提示
    @State private var uploadMessage: String?
    @State private var showUploadMessage = false

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
                    hasLocatedUser: $hasLocatedUser,
                    trackingPath: $locationManager.pathCoordinates,
                    pathUpdateVersion: locationManager.pathUpdateVersion,
                    isTracking: locationManager.isTracking,
                    isPathClosed: locationManager.isPathClosed,
                    territories: territories,
                    currentUserId: authManager.currentUser?.id.uuidString
                )
                .id(mapID) // 当 mapID 变化时，强制重建整个地图视图
                .ignoresSafeArea()
            } else {
                // 未授权：显示占位视图
                permissionPromptView
            }

            // 右下角：按钮组
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    if locationManager.isAuthorized {
                        VStack(spacing: 16) {
                            // 确认登记按钮（只在验证通过且已闭环时显示）
                            if locationManager.territoryValidationPassed && locationManager.isPathClosed {
                                confirmTerritoryButton
                            }

                            // 圈地按钮
                            trackingButton

                            // 定位按钮
                            locateButton
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 100) // 避免遮挡标签栏
                    }
                }
            }

            // 被拒绝时的提示卡片
            if locationManager.isDenied {
                deniedPermissionCard
            }

            // 速度警告横幅
            if let warning = locationManager.speedWarning {
                VStack {
                    speedWarningBanner(warning: warning)
                        .padding(.top, 60) // 避免遮挡状态栏
                    Spacer()
                }
            }

            // 验证结果横幅
            if showValidationBanner {
                VStack {
                    validationResultBanner
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 上传结果提示横幅
            if showUploadMessage, let message = uploadMessage {
                VStack {
                    uploadMessageBanner(message: message)
                        .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            handleOnAppear()
        }
        .onReceive(locationManager.$shouldShowValidationBanner) { shouldShow in
            // 监听验证横幅触发标志
            if shouldShow {
                // 延迟一点点，等待验证结果更新
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        showValidationBanner = true
                    }
                    // 3 秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showValidationBanner = false
                        }
                        // 重置标志
                        locationManager.shouldShowValidationBanner = false
                    }
                }
            }
        }
        .onChange(of: locationManager.speedWarning) { _, newWarning in
            // 警告出现后 3 秒自动消失
            if newWarning != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    locationManager.speedWarning = nil
                }
            }
        }
        .onChange(of: languageManager.currentLanguage) { oldValue, newValue in
            handleLanguageChange(from: oldValue, to: newValue)
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

    /// 确认登记按钮
    private var confirmTerritoryButton: some View {
        Button(action: {
            Task {
                await uploadCurrentTerritory()
            }
        }) {
            HStack(spacing: 8) {
                // 图标
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                }

                // 文本
                Text(isUploading ? "上传中..." : "确认登记")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.green)
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 5)
        }
        .disabled(isUploading)
    }

    /// 圈地按钮
    private var trackingButton: some View {
        Button(action: {
            toggleTracking()
        }) {
            HStack(spacing: 8) {
                // 图标
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 16))

                // 文本
                VStack(alignment: .leading, spacing: 2) {
                    Text(locationManager.isTracking ? "停止圈地" : "开始圈地")
                        .font(.system(size: 14, weight: .semibold))

                    // 追踪中显示点数
                    if locationManager.isTracking {
                        Text("\(locationManager.pathCoordinates.count) 点")
                            .font(.system(size: 11))
                    }
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                locationManager.isTracking
                    ? Color.red
                    : ApocalypseTheme.primary
            )
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 5)
        }
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

    /// 速度警告横幅
    private func speedWarningBanner(warning: String) -> some View {
        HStack(spacing: 12) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)

            // 警告文字
            Text(warning)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            // 根据是否还在追踪显示不同颜色
            locationManager.isTracking
                ? Color.orange // 警告：橙色
                : Color.red    // 已停止：红色
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 8)
        .padding(.horizontal, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(), value: locationManager.speedWarning)
    }

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                    ? "checkmark.circle.fill"
                    : "xmark.circle.fill")
                .font(.body)
            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .padding(.top, 50)
    }

    /// 上传结果提示横幅
    private func uploadMessageBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: message.contains("成功") ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.body)
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(message.contains("成功") ? Color.green : Color.red)
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

        // 加载领地
        Task {
            await loadTerritories()
        }
    }

    /// 重新居中地图（用户手动点击定位按钮）
    private func recenterMap() {
        guard userLocation != nil else {
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

    /// 切换路径追踪状态
    private func toggleTracking() {
        if locationManager.isTracking {
            // 停止追踪
            locationManager.stopPathTracking()
            print("🛑 用户停止圈地")
        } else {
            // 开始追踪
            locationManager.startPathTracking()
            print("🚩 用户开始圈地")
        }
    }

    /// 打开系统设置
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    /// 上传当前领地
    private func uploadCurrentTerritory() async {
        // ⚠️ 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            showUploadError("领地验证未通过，无法上传")
            return
        }

        // 标记为上传中
        isUploading = true

        // 保存数据（在清空之前）
        let coordinates = locationManager.pathCoordinates
        let area = locationManager.calculatedArea
        let startTime = Date() // TODO: 如果需要，可以保存实际的开始时间

        do {
            // 上传领地
            try await territoryManager.uploadTerritory(
                coordinates: coordinates,
                area: area,
                startTime: startTime
            )

            // 上传成功
            showUploadSuccess("领地登记成功！")

            // ⚠️ 关键：上传成功后必须停止追踪并清空状态
            locationManager.stopPathTracking()

            // 刷新领地列表
            await loadTerritories()

        } catch {
            // 上传失败
            showUploadError("上传失败: \(error.localizedDescription)")
        }

        // 标记为非上传中
        isUploading = false
    }

    /// 显示上传成功提示
    private func showUploadSuccess(_ message: String) {
        uploadMessage = message
        withAnimation {
            showUploadMessage = true
        }

        // 3秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showUploadMessage = false
            }
        }
    }

    /// 显示上传错误提示
    private func showUploadError(_ message: String) {
        uploadMessage = message
        withAnimation {
            showUploadMessage = true
        }

        // 3秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showUploadMessage = false
            }
        }
    }

    /// 加载所有领地
    private func loadTerritories() async {
        do {
            territories = try await territoryManager.loadAllTerritories()
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
        }
    }

    /// 处理语言变化
    private func handleLanguageChange(from oldLanguage: AppLanguage, to newLanguage: AppLanguage) {
        print("🌍 地图检测到语言变化: \(oldLanguage.rawValue) -> \(newLanguage.rawValue)")

        // 强制重建地图视图（清除所有缓存的地图图块）
        mapID = UUID()

        // 重置定位状态，以便在新地图上重新定位
        hasLocatedUser = false

        print("🗺️ 地图视图已重建以应用新语言")
    }
}

#Preview {
    MapTabView()
}
