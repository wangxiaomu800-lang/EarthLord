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

    // MARK: - Day 19: 碰撞检测状态

    /// 碰撞检测定时器
    @State private var collisionCheckTimer: Timer?

    /// 碰撞警告消息
    @State private var collisionWarning: String?

    /// 是否显示碰撞警告
    @State private var showCollisionWarning = false

    /// 碰撞警告级别
    @State private var collisionWarningLevel: WarningLevel = .safe

    /// 圈地开始时间
    @State private var trackingStartTime: Date?

    // MARK: - 探索功能状态

    /// 探索管理器
    @ObservedObject var explorationManager = ExplorationManager.shared

    /// 背包管理器
    @ObservedObject var inventoryManager = InventoryManager.shared

    /// 是否显示探索结果
    @State private var showExplorationResult = false

    /// 探索结果数据
    @State private var explorationResult: ExplorationStats?

    /// 是否显示搜刮结果
    @State private var showScavengeResult = false

    /// 搜刮获得的物品
    @State private var scavengedItems: [RewardItem] = []

    /// 搜刮的 POI 名称
    @State private var scavengedPOIName: String = ""

    // MARK: - 计算属性

    /// 下一等级信息
    private var nextTierInfo: (target: Double, name: String)? {
        let distance = explorationManager.currentDistance

        if distance < 200 {
            return (200, "铜级")
        } else if distance < 500 {
            return (500, "银级")
        } else if distance < 1000 {
            return (1000, "金级")
        } else if distance < 2000 {
            return (2000, "钻石")
        } else {
            return nil // 已达最高级
        }
    }

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
                    currentUserId: authManager.currentUser?.id.uuidString,
                    pois: explorationManager.nearbyPOIs,
                    scavengedPOIIds: explorationManager.scavengedPOIIds
                )
                .id(mapID) // 当 mapID 变化时，强制重建整个地图视图
                .ignoresSafeArea()
            } else {
                // 未授权：显示占位视图
                permissionPromptView
            }

            // 左上角：GPS坐标显示
            VStack {
                HStack {
                    if locationManager.isAuthorized {
                        coordinatesOverlay
                            .padding(.leading, 16)
                            .padding(.top, 12) // 紧贴状态栏下方
                    }
                    Spacer()
                }
                Spacer()
            }

            // 右下角：确认登记按钮（单独一行）
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    if locationManager.isAuthorized {
                        // 确认登记按钮（只在验证通过且已闭环时显示）
                        if locationManager.territoryValidationPassed && locationManager.isPathClosed {
                            confirmTerritoryButton
                                .padding(.trailing, 20)
                                .padding(.bottom, 160) // 给下方按钮组留空间
                        }
                    }
                }
            }

            // 底部：三个按钮横向排列
            VStack {
                Spacer()

                if locationManager.isAuthorized {
                    HStack(spacing: 16) {
                        // 圈地按钮
                        trackingButton

                        // 定位按钮
                        locateButton

                        // 探索按钮
                        exploreButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 110) // 距离 TabBar 的间距
                }
            }

            // 被拒绝时的提示卡片
            if locationManager.isDenied {
                deniedPermissionCard
            }

            // 圈地速度警告横幅
            if let warning = locationManager.speedWarning {
                VStack {
                    speedWarningBanner(warning: warning, isTracking: true)
                        .padding(.top, 60) // 避免遮挡状态栏
                    Spacer()
                }
            }

            // 探索速度警告横幅
            if let warning = explorationManager.speedWarning {
                VStack {
                    explorationSpeedWarningBanner(warning: warning)
                        .padding(.top, 60) // 避免遮挡状态栏
                    Spacer()
                }
            }

            // 物品发现通知横幅
            if let notification = explorationManager.itemDiscoveryNotification {
                VStack {
                    itemDiscoveryBanner(message: notification)
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

            // Day 19: 碰撞警告横幅（分级颜色）
            if showCollisionWarning, let warning = collisionWarning {
                collisionWarningBanner(message: warning, level: collisionWarningLevel)
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
        .sheet(isPresented: $showExplorationResult) {
            if let result = explorationResult {
                ExplorationResultView(result: result)
            } else {
                // 显示探索失败
                ExplorationResultView(
                    result: nil,
                    errorMessage: explorationManager.failureReason ?? "探索失败"
                )
            }
        }
        .sheet(isPresented: $explorationManager.showPOIPopup) {
            if let poi = explorationManager.currentPOI {
                POIProximityPopup(
                    poi: poi,
                    onScavenge: {
                        handleScavenge(poi: poi)
                    },
                    onDismiss: {
                        explorationManager.showPOIPopup = false
                    }
                )
                .presentationDetents([.height(350)])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showScavengeResult) {
            ScavengeResultView(
                poiName: scavengedPOIName,
                items: scavengedItems,
                onConfirm: {
                    showScavengeResult = false
                }
            )
        }
    }

    // MARK: - 子视图

    /// GPS坐标显示覆盖层
    private var coordinatesOverlay: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.primary)

            if let location = userLocation ?? locationManager.userLocation {
                VStack(alignment: .leading, spacing: 2) {
                    Text("当前坐标")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            } else {
                Text("定位中...")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ApocalypseTheme.cardBackground.opacity(0.95))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }

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
                    Text(locationManager.isTracking ? NSLocalizedString("停止圈地", comment: "Stop claiming") : NSLocalizedString("开始圈地", comment: "Start claiming"))
                        .font(.system(size: 14, weight: .semibold))

                    // 追踪中显示点数
                    if locationManager.isTracking {
                        Text(String(format: NSLocalizedString("%lld 点", comment: "%lld points"), locationManager.pathCoordinates.count))
                            .font(.system(size: 11))
                    }
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                locationManager.isTracking
                    ? Color.red
                    : Color(red: 1.0, green: 0.42, blue: 0.21) // 橙色 #FF6B35
            )
            .cornerRadius(28)
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }

    /// 定位按钮
    private var locateButton: some View {
        Button(action: {
            recenterMap()
        }) {
            Image(systemName: hasLocatedUser ? "location.fill" : "location")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color(red: 1.0, green: 0.42, blue: 0.21)) // 橙色 #FF6B35
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }

    /// 探索按钮
    private var exploreButton: some View {
        Button(action: {
            toggleExploration()
        }) {
            HStack(spacing: 8) {
                // 图标
                Image(systemName: explorationManager.isExploring ? "stop.fill" : "binoculars.fill")
                    .font(.system(size: 16))

                // 文本和数据
                VStack(alignment: .leading, spacing: 2) {
                    Text(explorationManager.isExploring ? NSLocalizedString("结束探索", comment: "End exploration") : NSLocalizedString("探索", comment: "Explore"))
                        .font(.system(size: 14, weight: .semibold))

                    // 探索中显示距离和下一等级
                    if explorationManager.isExploring {
                        if let nextTier = nextTierInfo {
                            // 显示距离和下一等级进度
                            Text("\(Int(explorationManager.currentDistance))m / \(Int(nextTier.target))m \(nextTier.name)")
                                .font(.system(size: 11))
                        } else {
                            // 已达最高级，只显示距离
                            Text("\(Int(explorationManager.currentDistance))m 钻石")
                                .font(.system(size: 11))
                        }
                    }
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                explorationManager.isExploring
                    ? Color.red
                    : Color(red: 1.0, green: 0.42, blue: 0.21) // 橙色 #FF6B35
            )
            .cornerRadius(28)
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }

    /// 圈地速度警告横幅
    private func speedWarningBanner(warning: String, isTracking: Bool) -> some View {
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
            isTracking
                ? Color.orange // 警告：橙色
                : Color.red    // 已停止：红色
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 8)
        .padding(.horizontal, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(), value: locationManager.speedWarning)
    }

    /// 探索速度警告横幅
    private func explorationSpeedWarningBanner(warning: String) -> some View {
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
            // 根据是否还在探索显示不同颜色
            explorationManager.isExploring
                ? Color.orange // 警告：橙色
                : Color.red    // 已停止：红色
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 8)
        .padding(.horizontal, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(), value: explorationManager.speedWarning)
    }

    /// 物品发现通知横幅
    private func itemDiscoveryBanner(message: String) -> some View {
        HStack(spacing: 12) {
            // 礼物图标
            Image(systemName: "gift.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)

            // 通知文字
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    ApocalypseTheme.success,
                    ApocalypseTheme.success.opacity(0.8)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 8)
        .padding(.horizontal, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(), value: explorationManager.itemDiscoveryNotification)
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

    /// Day 19: 碰撞警告横幅（分级颜色）
    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return VStack {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 18))

                Text(message)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundColor.opacity(0.95))
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .padding(.top, 120)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: showCollisionWarning)
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

    /// 切换探索状态
    private func toggleExploration() {
        if explorationManager.isExploring {
            // 结束探索
            Task {
                await endExploration()
            }
        } else {
            // 开始探索
            explorationManager.startExploration()
        }
    }

    /// 结束探索并处理奖励
    private func endExploration() async {
        print("\n🏁 ========== 结束探索 ==========")

        // 1. 停止探索管理器
        let result = explorationManager.stopExploration()
        print("   📊 探索结果: \(result.distance)m, \(result.duration)s")

        // 2. 检查是否探索失败
        if explorationManager.explorationFailed {
            print("   ❌ 探索失败: \(explorationManager.failureReason ?? "未知原因")")
            print("🏁 ========== 结束处理 ==========\n")

            // 显示失败结果
            explorationResult = nil
            showExplorationResult = true
            return
        }

        // 3. 生成奖励
        print("   🎁 生成奖励...")
        let reward = RewardGenerator.generateReward(distance: result.distance)
        print("      等级: \(reward.tier.rawValue)")
        print("      物品数: \(reward.items.count)")
        for (index, item) in reward.items.enumerated() {
            print("      [\(index + 1)] \(item.itemId) x\(item.quantity) (品质: \(item.quality ?? -1))")
        }

        // 4. 保存探索记录到数据库
        do {
            print("   💾 保存探索记录到数据库...")
            try await saveExplorationSession(
                distance: result.distance,
                duration: result.duration,
                startLocation: result.startLocation,
                endLocation: result.endLocation,
                rewardTier: reward.tier,
                items: reward.items
            )
            print("      ✅ 探索记录保存成功")
        } catch {
            print("      ❌ 保存探索记录失败: \(error)")
        }

        // 5. 添加物品到背包
        if !reward.items.isEmpty {
            do {
                print("   📦 调用 inventoryManager.addItems...")
                try await inventoryManager.addItems(reward.items)
                print("   ✅ 物品已成功添加到背包")
            } catch {
                print("   ❌ 添加物品到背包失败: \(error)")
            }
        } else {
            print("   ℹ️ 没有获得物品")
        }

        // 6. 构建探索结果数据
        print("   📋 构建探索结果数据...")
        let obtainedItems = reward.items.map { item in
            ObtainedItem(
                id: UUID().uuidString,
                itemId: item.itemId,
                quantity: item.quantity,
                quality: item.quality.map { ItemQuality(rawValue: $0) } ?? nil
            )
        }

        explorationResult = ExplorationStats(
            walkingDistance: result.distance,
            totalDistance: result.distance, // TODO: 累计距离需要从数据库查询
            distanceRank: 1, // TODO: 排名需要从数据库计算
            duration: result.duration,
            obtainedItems: obtainedItems
        )

        // 7. 显示探索结果
        print("   📱 显示探索结果界面")
        showExplorationResult = true
        print("🏁 ========== 结束处理完成 ==========\n")
    }

    /// 处理 POI 搜刮（异步版本）
    private func handleScavenge(poi: POI) {
        print("\n🎒 ========== 开始搜刮 POI ==========")
        print("   📍 地点: \(poi.name)")

        // 关闭接近弹窗
        explorationManager.showPOIPopup = false

        // 异步生成物品并添加到背包
        Task {
            // 1. 调用 AI 生成物品（异步）
            let items = await explorationManager.scavengePOI(poi)
            scavengedItems = items
            scavengedPOIName = poi.name
            print("   🎁 生成了 \(items.count) 件物品")

            // 2. 添加到背包
            do {
                try await inventoryManager.addItems(items)
                print("   ✅ 物品已添加到背包")

                // 3. 显示结果
                showScavengeResult = true
            } catch {
                print("   ❌ 添加物品失败: \(error)")
            }

            print("🎒 ========== 搜刮处理完成 ==========\n")
        }
    }

    /// 保存探索记录到数据库
    private func saveExplorationSession(
        distance: Double,
        duration: TimeInterval,
        startLocation: CLLocationCoordinate2D?,
        endLocation: CLLocationCoordinate2D?,
        rewardTier: RewardTier,
        items: [RewardItem]
    ) async throws {
        let supabase = SupabaseConfig.shared

        guard let userId = try? await supabase.auth.session.user.id else {
            print("❌ 用户未登录")
            return
        }

        // 使用 Encodable 结构体
        struct ExplorationSessionInsert: Encodable {
            let user_id: UUID
            let start_time: Date
            let end_time: Date
            let duration: Int
            let start_lat: Double?
            let start_lng: Double?
            let end_lat: Double?
            let end_lng: Double?
            let total_distance: Double
            let reward_tier: String
            let status: String
        }

        let session = ExplorationSessionInsert(
            user_id: userId,
            start_time: Date().addingTimeInterval(-duration),
            end_time: Date(),
            duration: Int(duration),
            start_lat: startLocation?.latitude,
            start_lng: startLocation?.longitude,
            end_lat: endLocation?.latitude,
            end_lng: endLocation?.longitude,
            total_distance: distance,
            reward_tier: rewardTier.rawValue,
            status: "completed"
        )

        try await supabase
            .from("exploration_sessions")
            .insert(session)
            .execute()

        print("✅ 探索记录已保存")
    }

    /// 切换路径追踪状态
    private func toggleTracking() {
        if locationManager.isTracking {
            // 停止追踪
            stopCollisionMonitoring()  // Day 19: 完全停止，清除警告
            locationManager.stopPathTracking()
            trackingStartTime = nil
            print("🛑 用户停止圈地")
        } else {
            // Day 19: 带碰撞检测的开始圈地
            startClaimingWithCollisionCheck()
        }
    }

    // MARK: - Day 19: 碰撞检测方法

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        guard let location = locationManager.userLocation,
              let userId = authManager.currentUser?.id.uuidString else {
            return
        }

        // 检测起始点是否在他人领地内
        let result = territoryManager.checkPointCollision(
            location: location,
            currentUserId: userId,
            territories: territories
        )

        if result.hasCollision {
            // 起点在他人领地内，显示错误并震动
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)

            TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

            // 3秒后隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }

            return
        }

        // 起点安全，开始圈地
        TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
        trackingStartTime = Date()
        locationManager.startPathTracking()
        startCollisionMonitoring()
    }

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 每 10 秒检测一次
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [self] _ in
            performCollisionCheck()
        }

        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
        TerritoryLogger.shared.log("碰撞检测定时器已停止", type: .info)
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        // 清除警告状态
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        guard locationManager.isTracking,
              let userId = authManager.currentUser?.id.uuidString else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        let result = territoryManager.checkPathCollisionComprehensive(
            path: path,
            currentUserId: userId,
            territories: territories
        )

        // 根据预警级别处理
        switch result.warningLevel {
        case .safe:
            // 安全，隐藏警告横幅
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe

        case .caution:
            // 注意（50-100m）- 黄色横幅 + 轻震 1 次
            collisionWarning = result.message
            collisionWarningLevel = .caution
            showCollisionWarning = true
            triggerHapticFeedback(level: .caution)

        case .warning:
            // 警告（25-50m）- 橙色横幅 + 中震 2 次
            collisionWarning = result.message
            collisionWarningLevel = .warning
            showCollisionWarning = true
            triggerHapticFeedback(level: .warning)

        case .danger:
            // 危险（<25m）- 红色横幅 + 强震 3 次
            collisionWarning = result.message
            collisionWarningLevel = .danger
            showCollisionWarning = true
            triggerHapticFeedback(level: .danger)

        case .violation:
            // 【关键修复】违规处理 - 必须先显示横幅，再停止！

            // 1. 先设置警告状态（让横幅显示出来）
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 2. 触发震动
            triggerHapticFeedback(level: .violation)

            // 3. 只停止定时器，不清除警告状态！
            stopCollisionCheckTimer()

            // 4. 停止圈地追踪
            locationManager.stopPathTracking()
            trackingStartTime = nil

            TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

            // 5. 5秒后再清除警告横幅
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }
        }
    }

    /// Day 19: 触发震动反馈
    private func triggerHapticFeedback(level: WarningLevel) {
        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .warning:
            // 警告：中震 2 次
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }

        case .danger:
            // 危险：强震 3 次
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred()
            }

        case .violation:
            // 违规：错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
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
            stopCollisionMonitoring()  // Day 19: 完全停止，清除警告
            locationManager.stopPathTracking()
            trackingStartTime = nil

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
