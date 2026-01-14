//
//  ScavengeResultView.swift
//  EarthLord
//
//  POI 搜刮结果视图
//  显示搜刮获得的物品
//

import SwiftUI

struct ScavengeResultView: View {
    // MARK: - 参数
    let poiName: String
    let items: [RewardItem]
    let onConfirm: () -> Void

    // MARK: - 状态
    @State private var showContent = false
    @State private var showItems = false

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 成功标题
                successHeader()
                    .padding(.top, 40)

                Spacer()

                // 物品卡片
                itemsCard()
                    .padding(.horizontal, 20)

                Spacer()

                // 确认按钮
                confirmButton()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            // 入场动画
            withAnimation(.easeOut(duration: 0.5)) {
                showContent = true
            }

            // 物品列表动画（延迟0.5秒）
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                showItems = true
            }
        }
    }

    // MARK: - 子视图

    /// 成功标题区域
    private func successHeader() -> some View {
        VStack(spacing: 16) {
            // 图标动画
            ZStack {
                // 外圈光晕
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.success.opacity(0.3),
                                ApocalypseTheme.success.opacity(0)
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
                    .fill(ApocalypseTheme.success.opacity(0.2))
                    .frame(width: 100, height: 100)

                // 图标
                Image(systemName: "bag.fill")
                    .font(.system(size: 50))
                    .foregroundColor(ApocalypseTheme.success)
            }
            .scaleEffect(showContent ? 1.0 : 0.3)
            .opacity(showContent ? 1.0 : 0)

            // 标题文字
            VStack(spacing: 8) {
                Text("🎉 搜刮成功！")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                    Text(poiName)
                        .font(.subheadline)
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .scaleEffect(showContent ? 1.0 : 0.8)
            .opacity(showContent ? 1.0 : 0)
        }
    }

    /// 物品卡片
    private func itemsCard() -> some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(ApocalypseTheme.warning)

                Text("获得物品")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(items.count) 件")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 物品列表
            if items.isEmpty {
                // 空状态（理论上不会出现）
                VStack(spacing: 16) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 50))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("什么都没找到")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        ScavengeItemRow(
                            item: item,
                            delay: Double(index) * 0.1,
                            showItems: showItems
                        )
                    }
                }
            }

            // 底部提示
            if !items.isEmpty {
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
    private func confirmButton() -> some View {
        Button(action: {
            onConfirm()
        }) {
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

// MARK: - 搜刮物品行组件

/// 搜刮物品行
private struct ScavengeItemRow: View {
    let item: RewardItem
    let delay: Double
    let showItems: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(categoryColor().opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: categoryIcon())
                    .font(.title3)
                    .foregroundColor(categoryColor())
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(itemName())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 品质标签
                    if let quality = item.quality, let qualityEnum = ItemQuality(rawValue: quality) {
                        Text(qualityEnum.displayName)
                            .font(.system(size: 10))
                            .foregroundColor(qualityColor(qualityEnum))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(qualityColor(qualityEnum).opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                // 物品 ID（作为临时显示）
                Text(item.itemId)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()

            // 数量
            Text("x\(item.quantity)")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.warning)

            // 对勾（带弹跳效果）
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(showItems ? 1.0 : 0.3)
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.5).delay(delay + 0.2),
                    value: showItems
                )
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(ApocalypseTheme.background.opacity(0.5))
        .cornerRadius(8)
        .scaleEffect(showItems ? 1.0 : 0.8)
        .opacity(showItems ? 1.0 : 0)
        .animation(.easeOut(duration: 0.3).delay(delay), value: showItems)
    }

    // MARK: - 辅助方法

    /// 获取物品名称
    private func itemName() -> String {
        if let definition = MockExplorationData.findItemDefinition(by: item.itemId) {
            return definition.name
        }
        return item.itemId
    }

    /// 获取分类图标
    private func categoryIcon() -> String {
        if let definition = MockExplorationData.findItemDefinition(by: item.itemId) {
            return definition.category.iconName
        }
        return "cube.fill"
    }

    /// 获取分类颜色
    private func categoryColor() -> Color {
        if let definition = MockExplorationData.findItemDefinition(by: item.itemId) {
            return definition.category.themeColor
        }
        return ApocalypseTheme.textSecondary
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
    let sampleItems: [RewardItem] = [
        RewardItem(itemId: "item_water_bottle", quantity: 2, quality: nil),
        RewardItem(itemId: "item_canned_food", quantity: 1, quality: 2),
        RewardItem(itemId: "item_bandage", quantity: 3, quality: 3)
    ]

    return ScavengeResultView(
        poiName: "沃尔玛超市",
        items: sampleItems,
        onConfirm: {
            print("确认")
        }
    )
}
