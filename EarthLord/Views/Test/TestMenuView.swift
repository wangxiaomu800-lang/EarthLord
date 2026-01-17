//
//  TestMenuView.swift
//  EarthLord
//
//  测试模块入口菜单
//  提供 Supabase 测试和圈地测试的入口
//

import SwiftUI

struct TestMenuView: View {
    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background.ignoresSafeArea()

            List {
                // Supabase 连接测试
                NavigationLink(destination: SupabaseTestView()) {
                    HStack(spacing: 16) {
                        // 图标
                        Image(systemName: "network")
                            .font(.system(size: 24))
                            .foregroundColor(ApocalypseTheme.primary)
                            .frame(width: 40, height: 40)
                            .background(ApocalypseTheme.primary.opacity(0.1))
                            .cornerRadius(8)

                        // 标题和描述
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("数据库连接测试", comment: "Database connection test"))
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text(NSLocalizedString("测试数据库连接状态", comment: "Test database connection status"))
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(ApocalypseTheme.cardBackground)

                // 圈地功能测试
                NavigationLink(destination: TerritoryTestView()) {
                    HStack(spacing: 16) {
                        // 图标
                        Image(systemName: "flag.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                            .frame(width: 40, height: 40)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)

                        // 标题和描述
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("圈地功能测试", comment: "Territory claiming test"))
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Text(NSLocalizedString("查看圈地模块运行日志", comment: "View territory module logs"))
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(ApocalypseTheme.cardBackground)
            }
            .scrollContentBackground(.hidden) // 隐藏 List 默认背景
        }
        .navigationTitle(NSLocalizedString("开发测试", comment: "Development test"))
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        TestMenuView()
    }
}
