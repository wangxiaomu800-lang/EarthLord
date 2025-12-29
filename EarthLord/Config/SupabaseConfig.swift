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
        return SupabaseClient(
            supabaseURL: URL(string: "https://vuqfufnrxzsmkzmhtuhw.supabase.co")!,
            supabaseKey: "sb_publishable_sej6ww803g00vIuiXFjhFQ_JdRV2QHk",
            options: clientOptions
        )
    }()
}
