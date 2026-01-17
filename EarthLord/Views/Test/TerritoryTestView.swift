//
//  TerritoryTestView.swift
//  EarthLord
//
//  圈地功能测试界面
//  实时显示圈地模块的调试日志
//

import SwiftUI

struct TerritoryTestView: View {
    // MARK: - 观察对象

    /// 定位管理器（监听追踪状态）
    @ObservedObject var locationManager = LocationManager.shared

    /// 日志管理器（监听日志更新）
    @ObservedObject var logger = TerritoryLogger.shared

    // MARK: - 视图主体

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 状态指示器
                statusIndicator
                    .padding(.vertical, 16)
                    .background(ApocalypseTheme.cardBackground)

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 日志区域
                logScrollView
                    .padding(.top, 16)

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 底部按钮
                actionButtons
                    .padding(.vertical, 16)
                    .background(ApocalypseTheme.cardBackground)
            }
        }
        .navigationTitle(NSLocalizedString("圈地测试", comment: "Territory test"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 子视图

    /// 状态指示器
    private var statusIndicator: some View {
        HStack(spacing: 12) {
            // 状态点
            Circle()
                .fill(locationManager.isTracking ? Color.green : Color.gray)
                .frame(width: 12, height: 12)

            // 状态文字
            Text(locationManager.isTracking ? NSLocalizedString("追踪中", comment: "Tracking") : NSLocalizedString("未追踪", comment: "Not tracking"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 点数统计
            if locationManager.isTracking {
                Text("(\(locationManager.pathCoordinates.count)" + NSLocalizedString(" 点", comment: " points") + ")")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    /// 日志滚动区域
    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if logger.logs.isEmpty {
                        // 空状态提示
                        Text(NSLocalizedString("暂无日志\n\n请在「地图」Tab 中开始圈地，\n日志将在这里实时显示", comment: "No logs yet. Start claiming territory in the Map tab, and logs will appear here"))
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        // 日志列表
                        ForEach(logger.logs) { entry in
                            logEntryView(entry)
                                .id(entry.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: logger.logs.count) { _, _ in
                // 日志更新时自动滚动到底部
                if let lastLog = logger.logs.last {
                    withAnimation {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    /// 日志条目视图
    private func logEntryView(_ entry: LogEntry) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: entry.timestamp)

        return HStack(alignment: .top, spacing: 8) {
            // 时间戳
            Text("[\(timestamp)]")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 80, alignment: .leading)

            // 类型标签
            Text("[\(entry.type.rawValue)]")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(entry.type.color)
                .frame(width: 70, alignment: .leading)

            // 消息
            Text(entry.message)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    /// 底部操作按钮
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // 清空日志按钮
            Button(action: {
                logger.clear()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text(NSLocalizedString("清空日志", comment: "Clear logs"))
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.8))
                .cornerRadius(8)
            }

            // 导出日志按钮
            ShareLink(item: logger.export()) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text(NSLocalizedString("导出日志", comment: "Export logs"))
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.primary)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    NavigationStack {
        TerritoryTestView()
    }
}
