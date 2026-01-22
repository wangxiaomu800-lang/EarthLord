//
//  TerritoryTabView.swift
//  EarthLord
//
//  领地管理视图
//  显示用户的领地列表、统计信息、详情页
//

import SwiftUI

struct TerritoryTabView: View {
    // MARK: - 依赖注入

    @EnvironmentObject var authManager: AuthManager

    // MARK: - 状态

    /// 我的领地列表
    @State private var myTerritories: [Territory] = []

    /// 是否正在加载
    @State private var isLoading = false

    /// 是否显示详情页
    @State private var showingDetail = false

    /// 选中的领地
    @State private var selectedTerritory: Territory?

    // MARK: - 计算属性

    /// 领地总数
    private var territoryCount: Int {
        return myTerritories.count
    }

    /// 领地总面积（平方米）
    private var totalArea: Double {
        return myTerritories.reduce(0) { $0 + $1.area }
    }

    /// 格式化总面积
    private var formattedTotalArea: String {
        if totalArea >= 1_000_000 {
            return String(format: "%.2f km²", totalArea / 1_000_000)
        } else {
            return String(format: "%.0f m²", totalArea)
        }
    }

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading && myTerritories.isEmpty {
                    // 加载中
                    ProgressView(NSLocalizedString("加载中...", comment: "Loading..."))
                } else if myTerritories.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 领地列表
                    ScrollView {
                        VStack(spacing: 20) {
                            // 统计头部
                            statisticsHeader

                            // 领地卡片列表
                            VStack(spacing: 12) {
                                ForEach(myTerritories) { territory in
                                    TerritoryCard(territory: territory)
                                        .onTapGesture {
                                            selectedTerritory = territory
                                            showingDetail = true
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                    }
                    .refreshable {
                        await loadTerritories()
                    }
                }
            }
            .navigationTitle(NSLocalizedString("我的领地", comment: "My Territories"))
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadTerritories()
            }
            .onReceive(NotificationCenter.default.publisher(for: .territoryUpdated)) { _ in
                Task {
                    await loadTerritories()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .territoryDeleted)) { _ in
                Task {
                    await loadTerritories()
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let territory = selectedTerritory {
                    TerritoryDetailView(territory: territory, onDelete: {
                        Task {
                            await loadTerritories()
                        }
                    })
                }
            }
        }
    }

    // MARK: - 子视图

    /// 统计头部
    private var statisticsHeader: some View {
        HStack(spacing: 20) {
            // 领地数量
            StatisticItem(
                icon: "flag.fill",
                title: NSLocalizedString("领地数量", comment: "Territory count"),
                value: "\(territoryCount)",
                color: .green
            )

            // 总面积
            StatisticItem(
                icon: "map.fill",
                title: NSLocalizedString("总面积", comment: "Total area"),
                value: formattedTotalArea,
                color: .orange
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(NSLocalizedString("还没有领地", comment: "No territories yet"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(NSLocalizedString("去地图上圈地吧", comment: "Go claim territory on the map"))
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 数据加载

    /// 加载我的领地
    private func loadTerritories() async {
        isLoading = true
        defer { isLoading = false }

        do {
            myTerritories = try await TerritoryManager.shared.loadMyTerritories()
            print("✅ 加载了 \(myTerritories.count) 个领地")
        } catch {
            print("❌ 加载领地失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 统计项组件

/// 统计项视图
private struct StatisticItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 领地卡片组件

/// 领地卡片视图
private struct TerritoryCard: View {
    let territory: Territory

    /// 格式化时间显示
    private var formattedDate: String {
        guard let createdAt = territory.createdAt else {
            return NSLocalizedString("未知时间", comment: "Unknown time")
        }

        // PostgreSQL 返回格式：2026-01-08 05:25:59.679755+00
        // 需要转换为标准 ISO8601 格式
        let standardISOString = createdAt
            .replacingOccurrences(of: " ", with: "T")
            .replacingOccurrences(of: "+00", with: "+00:00")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: standardISOString) else {
            // 如果 ISO8601 失败，尝试直接解析
            let fallbackFormatter = DateFormatter()
            fallbackFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
            fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
            fallbackFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            guard let fallbackDate = fallbackFormatter.date(from: createdAt) else {
                return NSLocalizedString("未知时间", comment: "Unknown time")
            }

            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            displayFormatter.locale = Locale.current

            return displayFormatter.string(from: fallbackDate)
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        displayFormatter.locale = Locale.current

        return displayFormatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundColor(.green)

                Text(territory.displayName)
                    .font(.headline)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 信息行
            HStack {
                Label(territory.formattedArea, systemImage: "map")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                if let pointCount = territory.pointCount {
                    Label(String(format: NSLocalizedString("%d 点", comment: "%d points"), pointCount), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // 时间行
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 预览

#Preview {
    TerritoryTabView()
        .environmentObject(AuthManager())
}
