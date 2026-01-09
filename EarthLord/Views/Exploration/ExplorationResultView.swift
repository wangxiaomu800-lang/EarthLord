//
//  ExplorationResultView.swift
//  EarthLord
//
//  探索结果弹窗页面
//  显示本次探索的统计数据和获得的物品奖励
//

import SwiftUI

struct ExplorationResultView: View {
    // MARK: - 属性

    /// 探索结果数据
    let result: ExplorationStats

    /// 关闭回调
    @Environment(\.dismiss) var dismiss

    // MARK: - 状态

    /// 动画状态：是否显示内容
    @State private var showContent = false

    /// 动画状态：是否显示物品
    @State private var showItems = false

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 成就标题
                        achievementHeader
                            .padding(.top, 20)

                        // 统计数据卡片
                        statsCard

                        // 奖励物品卡片
                        rewardsCard

                        // 确认按钮
                        confirmButton
                            .padding(.top, 8)
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                // 入场动画
                withAnimation(.easeOut(duration: 0.5)) {
                    showContent = true
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                    showItems = true
                }
            }
        }
    }

    // MARK: - 子视图

    /// 成就标题区域
    private var achievementHeader: some View {
        VStack(spacing: 16) {
            // 大图标（带动画）
            ZStack {
                // 外圈光晕
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.primary.opacity(0.3),
                                ApocalypseTheme.primary.opacity(0)
                            ]),
                            center: .center,
                            startRadius: 40,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(showContent ? 1.0 : 0.5)
                    .opacity(showContent ? 1.0 : 0)

                // 内圈背景
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 100, height: 100)

                // 图标
                Image(systemName: "map.fill")
                    .font(.system(size: 50))
                    .foregroundColor(ApocalypseTheme.primary)
            }
            .scaleEffect(showContent ? 1.0 : 0.3)
            .opacity(showContent ? 1.0 : 0)

            // 标题文字
            VStack(spacing: 8) {
                Text("探索完成！")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("你发现了新的区域")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .scaleEffect(showContent ? 1.0 : 0.8)
            .opacity(showContent ? 1.0 : 0)
        }
    }

    /// 统计数据卡片
    private var statsCard: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(ApocalypseTheme.info)

                Text("探索统计")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            // 行走距离
            StatRow(
                icon: "figure.walk",
                title: "行走距离",
                currentValue: MockExplorationData.formatDistance(result.walkingDistance),
                totalValue: "累计 " + MockExplorationData.formatDistance(result.totalDistance),
                rank: result.distanceRank
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 探索面积
            StatRow(
                icon: "square.dashed",
                title: "探索面积",
                currentValue: MockExplorationData.formatArea(result.exploredArea),
                totalValue: "累计 " + MockExplorationData.formatArea(result.totalArea),
                rank: result.areaRank
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 探索时长
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(width: 24)

                Text("探索时长")
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text(MockExplorationData.formatDuration(result.duration))
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .scaleEffect(showContent ? 1.0 : 0.9)
        .opacity(showContent ? 1.0 : 0)
    }

    /// 奖励物品卡片
    private var rewardsCard: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(ApocalypseTheme.warning)

                Text("获得物品")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(result.obtainedItems.count) 件")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 物品列表
            if result.obtainedItems.isEmpty {
                // 空状态
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title)
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("这次什么都没找到...")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(result.obtainedItems.enumerated()), id: \.element.id) { index, item in
                        if let definition = MockExplorationData.findItemDefinition(by: item.itemId) {
                            RewardItemRow(
                                definition: definition,
                                quantity: item.quantity,
                                quality: item.quality,
                                delay: Double(index) * 0.1,
                                showItems: showItems
                            )
                        }
                    }
                }
            }

            // 底部提示
            if !result.obtainedItems.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.success)

                    Text("已添加到背包")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.success)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .scaleEffect(showContent ? 1.0 : 0.9)
        .opacity(showContent ? 1.0 : 0)
    }

    /// 确认按钮
    private var confirmButton: some View {
        Button(action: { dismiss() }) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.headline)

                Text("确认收下")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundColor(.white)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        ApocalypseTheme.success,
                        ApocalypseTheme.success.opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .scaleEffect(showContent ? 1.0 : 0.9)
        .opacity(showContent ? 1.0 : 0)
    }
}

// MARK: - 统计行组件

/// 统计数据行
private struct StatRow: View {
    let icon: String
    let title: String
    let currentValue: String
    let totalValue: String
    let rank: Int

    var body: some View {
        HStack(alignment: .top) {
            // 图标
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 24)

            // 标题和累计
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(totalValue)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()

            // 当前值和排名
            VStack(alignment: .trailing, spacing: 4) {
                Text(currentValue)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 排名标签
                HStack(spacing: 2) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10))

                    Text("#\(rank)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(ApocalypseTheme.success)
            }
        }
    }
}

// MARK: - 奖励物品行组件

/// 奖励物品行
private struct RewardItemRow: View {
    let definition: ItemDefinition
    let quantity: Int
    let quality: ItemQuality?
    let delay: Double
    let showItems: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(definition.category.themeColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: definition.category.iconName)
                    .font(.title3)
                    .foregroundColor(definition.category.themeColor)
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(definition.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 品质标签
                    if let quality = quality {
                        Text(quality.displayName)
                            .font(.system(size: 10))
                            .foregroundColor(qualityColor(quality))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(qualityColor(quality).opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                // 稀有度
                Text(definition.rarity.displayName)
                    .font(.caption)
                    .foregroundColor(definition.rarity.themeColor)
            }

            Spacer()

            // 数量
            Text("x\(quantity)")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.warning)

            // 对勾
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(ApocalypseTheme.success)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(ApocalypseTheme.background.opacity(0.5))
        .cornerRadius(8)
        .scaleEffect(showItems ? 1.0 : 0.8)
        .opacity(showItems ? 1.0 : 0)
        .animation(.easeOut(duration: 0.3).delay(delay), value: showItems)
    }

    /// 品质颜色
    private func qualityColor(_ quality: ItemQuality) -> Color {
        switch quality {
        case .broken: return ApocalypseTheme.danger
        case .worn: return ApocalypseTheme.warning
        case .normal: return ApocalypseTheme.textSecondary
        case .good: return ApocalypseTheme.success
        case .excellent: return ApocalypseTheme.info
        }
    }
}

// MARK: - 预览

#Preview {
    ExplorationResultView(result: MockExplorationData.explorationResult)
}
