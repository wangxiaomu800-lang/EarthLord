import Foundation
import Supabase

/// Supabase 客户端配置和共享实例
enum SupabaseConfig {

    /// 共享的 Supabase 客户端实例
    static let shared: SupabaseClient = {
        // 配置 Auth 选项（启用新的会话行为）
        let authOptions = SupabaseClientOptions.AuthOptions(
            emitLocalSessionAsInitialSession: true
        )

        // 配置 Supabase 客户端选项
        let clientOptions = SupabaseClientOptions(
            auth: authOptions
        )

        // 创建并返回客户端
        // 注意：使用 Legacy Anon Key 以兼容 Edge Function 的 JWT 验证
        return SupabaseClient(
            supabaseURL: URL(string: "https://vuqfufnrxzsmkzmhtuhw.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ1cWZ1Zm5yeHpzbWt6bWh0dWh3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY3NDkzMjcsImV4cCI6MjA4MjMyNTMyN30.37-N8-CzZLsiDeanaIFxsL24SsefNPOKprokySwUVcM",
            options: clientOptions
        )
    }()
}
