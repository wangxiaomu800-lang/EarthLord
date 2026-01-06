//
//  TerritoryLogger.swift
//  EarthLord
//
//  圈地功能日志管理器
//  用于在真机测试时查看圈地模块的运行状态
//

import Foundation
import SwiftUI
import Combine

/// 日志类型
enum LogType: String {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"

    /// 日志类型对应的颜色
    var color: Color {
        switch self {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

/// 日志条目
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType
}

/// 圈地日志管理器
class TerritoryLogger: ObservableObject {
    // MARK: - 单例

    static let shared = TerritoryLogger()

    // MARK: - 发布属性

    /// 日志数组
    @Published var logs: [LogEntry] = []

    /// 格式化的日志文本（用于显示）
    @Published var logText: String = ""

    // MARK: - 私有属性

    /// 最大日志条数
    private let maxLogCount = 200

    /// 时间格式化器（显示用）
    private let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// 时间格式化器（导出用）
    private let exportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    // MARK: - 初始化

    private init() {
        print("📝 TerritoryLogger 已初始化")
    }

    // MARK: - 公开方法

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型
    func log(_ message: String, type: LogType = .info) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 创建日志条目
            let entry = LogEntry(timestamp: Date(), message: message, type: type)

            // 添加到数组
            self.logs.append(entry)

            // 限制日志条数
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst(self.logs.count - self.maxLogCount)
            }

            // 更新格式化文本
            self.updateLogText()

            // 打印到控制台
            print("[\(type.rawValue)] \(message)")
        }
    }

    /// 清空所有日志
    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
            self?.logText = ""
            print("📝 日志已清空")
        }
    }

    /// 导出日志为文本
    /// - Returns: 包含头信息的完整日志文本
    func export() -> String {
        let header = """
        === 圈地功能测试日志 ===
        导出时间: \(exportFormatter.string(from: Date()))
        日志条数: \(logs.count)

        """

        let logLines = logs.map { entry in
            let timestamp = exportFormatter.string(from: entry.timestamp)
            return "[\(timestamp)] [\(entry.type.rawValue)] \(entry.message)"
        }.joined(separator: "\n")

        return header + logLines
    }

    // MARK: - 私有方法

    /// 更新格式化的日志文本
    private func updateLogText() {
        logText = logs.map { entry in
            let timestamp = displayFormatter.string(from: entry.timestamp)
            return "[\(timestamp)] [\(entry.type.rawValue)] \(entry.message)"
        }.joined(separator: "\n")
    }
}
