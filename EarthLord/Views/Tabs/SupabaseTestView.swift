import SwiftUI
import Supabase

// 初始化 Supabase 客户端
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://vuqfufnrxzsmkzmhtuhw.supabase.co")!,
    supabaseKey: "sb_publishable_sej6ww803g00vIuiXFjhFQ_JdRV2QHk"
)

struct SupabaseTestView: View {
    @State private var isConnected: Bool? = nil
    @State private var debugLog: String = "点击按钮开始测试连接..."
    @State private var isTesting: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("Supabase 连接测试")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 40)

            // 状态图标
            if let connected = isConnected {
                Image(systemName: connected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(connected ? .green : .red)
                    .padding()
            } else {
                Image(systemName: "network")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                    .padding()
            }

            // 调试日志文本框
            ScrollView {
                Text(debugLog)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .frame(height: 300)
            .padding(.horizontal)

            // 测试连接按钮
            Button(action: {
                testConnection()
            }) {
                HStack {
                    if isTesting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(isTesting ? "测试中..." : "测试连接")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isTesting ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isTesting)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    // 测试连接函数
    func testConnection() {
        isTesting = true
        debugLog = "正在测试连接...\n"

        Task {
            // 步骤 1: 测试基本连接
            await MainActor.run {
                debugLog += "📡 步骤 1/2: 测试 Supabase 服务器连接...\n"
                debugLog += "URL: https://vuqfufnrxzsmkzmhtuhw.supabase.co\n\n"
            }

            do {
                // 使用 non_existent_table 测试基本连接
                let _: [String] = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                await MainActor.run {
                    debugLog += "✅ 基本连接成功（意外：表存在）\n\n"
                }
            } catch {
                let errorMessage = error.localizedDescription

                await MainActor.run {
                    debugLog += "响应: \(errorMessage)\n"

                    // 判断是否是连接成功但表不存在
                    if errorMessage.contains("PGRST") ||
                       errorMessage.contains("Could not find the table") ||
                       (errorMessage.contains("relation") && errorMessage.contains("does not exist")) {
                        debugLog += "✅ 基本连接成功（服务器已响应）\n\n"
                    } else if errorMessage.contains("hostname") ||
                              errorMessage.contains("URL") ||
                              errorMessage.contains("NSURLErrorDomain") {
                        isConnected = false
                        debugLog += "❌ 连接失败：无法访问服务器\n"
                        debugLog += "请检查：\n"
                        debugLog += "1. 网络连接是否正常\n"
                        debugLog += "2. Supabase URL 是否正确\n"
                        isTesting = false
                        return
                    } else {
                        isConnected = false
                        debugLog += "❌ 未知错误: \(errorMessage)\n"
                        isTesting = false
                        return
                    }
                }
            }

            // 步骤 2: 检查数据表是否存在
            await MainActor.run {
                debugLog += "📊 步骤 2/2: 检查数据表是否已创建...\n"
            }

            // 定义一个简单的 Profile 结构来接收数据
            struct ProfileTest: Decodable {
                let id: String?
                let username: String?
            }

            do {
                // 方法 1: 尝试使用 count() 检查表是否存在
                await MainActor.run {
                    debugLog += "尝试方法 1: 使用 count 查询...\n"
                }

                let countResponse = try await supabase
                    .from("profiles")
                    .select("*", head: true, count: .exact)
                    .execute()

                await MainActor.run {
                    debugLog += "✅ profiles 表存在（count 查询成功）\n"
                    debugLog += "表记录数: \(countResponse.count ?? 0)\n\n"
                }

                // 方法 2: 尝试查询具体列
                await MainActor.run {
                    debugLog += "尝试方法 2: 查询具体数据...\n"
                }

                let profiles: [ProfileTest] = try await supabase
                    .from("profiles")
                    .select("id, username")
                    .limit(5)
                    .execute()
                    .value

                await MainActor.run {
                    isConnected = true
                    debugLog += "✅ 成功查询 profiles 表！\n"
                    debugLog += "查询到 \(profiles.count) 条记录\n\n"

                    if profiles.isEmpty {
                        debugLog += "ℹ️ 表为空（这是正常的，因为还没有用户）\n\n"
                    } else {
                        debugLog += "示例数据:\n"
                        for (index, profile) in profiles.prefix(3).enumerated() {
                            debugLog += "\(index + 1). ID: \(profile.id ?? "null")\n"
                            debugLog += "   用户名: \(profile.username ?? "null")\n"
                        }
                        debugLog += "\n"
                    }

                    debugLog += "✅ 数据库配置完成！\n"
                    debugLog += "🎉 恭喜！Supabase 已完全配置成功！\n\n"
                    debugLog += "📝 你现在可以：\n"
                    debugLog += "1. 查询 profiles 表\n"
                    debugLog += "2. 查询 territories 表\n"
                    debugLog += "3. 查询 pois 表\n"
                    isTesting = false
                }
            } catch {
                let errorMessage = error.localizedDescription
                let fullError = String(describing: error)

                await MainActor.run {
                    debugLog += "❌ 查询出错\n\n"
                    debugLog += "错误类型: \(type(of: error))\n"
                    debugLog += "简短描述: \(errorMessage)\n"
                    debugLog += "完整错误: \(fullError)\n\n"

                    if errorMessage.contains("relation \"profiles\" does not exist") ||
                       errorMessage.contains("Could not find the table \"profiles\"") ||
                       fullError.contains("relation \"profiles\" does not exist") {
                        isConnected = false
                        debugLog += "⚠️ profiles 表不存在\n\n"
                        debugLog += "请执行 SQL migration:\n"
                        debugLog += "文件: supabase/migrations/20251226_create_core_tables.sql\n"
                    } else if errorMessage.contains("JWT") || errorMessage.contains("authentication") {
                        isConnected = false
                        debugLog += "⚠️ 认证问题\n"
                        debugLog += "可能原因: Supabase key 不正确\n"
                    } else if errorMessage.contains("RLS") || errorMessage.contains("policy") ||
                              fullError.contains("row-level security") {
                        isConnected = false
                        debugLog += "⚠️ RLS（行级安全）策略问题\n"
                        debugLog += "需要检查 RLS 策略配置\n"
                    } else {
                        isConnected = false
                        debugLog += "⚠️ 未知错误\n"
                        debugLog += "建议: 在 Supabase Dashboard 中手动测试查询\n"
                    }
                    isTesting = false
                }
            }
        }
    }
}

#Preview {
    SupabaseTestView()
}
