import SwiftUI
import Supabase

/// 认证管理器 - 管理用户注册、登录、密码重置等认证流程
@MainActor
class AuthManager: ObservableObject {

    // MARK: - Published Properties (发布属性)

    /// 用户是否已完全认证（已登录且完成所有必要步骤）
    @Published var isAuthenticated: Bool = false

    /// 是否需要设置密码（OTP验证后但未设置密码）
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published var currentUser: User? = nil

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误消息
    @Published var errorMessage: String? = nil

    /// OTP 是否已发送
    @Published var otpSent: Bool = false

    /// OTP 是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - Supabase Client

    private let supabase: SupabaseClient

    // MARK: - Initialization

    init(supabase: SupabaseClient = supabase) {
        self.supabase = supabase
    }

    // MARK: - 注册流程

    /// 步骤1: 发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送 OTP 验证码（shouldCreateUser: true 表示如果用户不存在则创建）
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            otpSent = true
            errorMessage = nil
            print("✅ 注册验证码已发送到: \(email)")

        } catch {
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            print("❌ 发送注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 步骤2: 验证注册验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    /// ⚠️ 注意: 验证成功后用户已登录，但需要设置密码才能完成注册
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP 验证码
            let response = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email  // 注册使用 .email 类型
            )

            // 验证成功后用户已登录，但还需要设置密码
            currentUser = response.user
            otpVerified = true
            needsPasswordSetup = true
            isAuthenticated = false  // ⚠️ 重要：注册流程未完成，保持 false

            print("✅ 验证码验证成功，用户已登录: \(response.user.email ?? "Unknown")")
            print("⚠️ 需要设置密码才能完成注册")

        } catch {
            errorMessage = "验证码错误或已过期: \(error.localizedDescription)"
            print("❌ 验证注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 步骤3: 完成注册（设置密码）
    /// - Parameter password: 用户密码
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            let response = try await supabase.auth.update(
                user: UserAttributes(password: password)
            )

            // 密码设置成功，注册流程完成
            currentUser = response.user
            needsPasswordSetup = false
            isAuthenticated = true  // ✅ 注册完成，设置为已认证

            print("✅ 注册完成: \(response.user.email ?? "Unknown")")

        } catch {
            errorMessage = "设置密码失败: \(error.localizedDescription)"
            print("❌ 完成注册失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 登录流程

    /// 使用邮箱和密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 使用邮箱和密码登录
            let response = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            // 登录成功
            currentUser = response.user
            isAuthenticated = true
            needsPasswordSetup = false

            print("✅ 登录成功: \(response.user.email ?? "Unknown")")

        } catch {
            errorMessage = "登录失败: 邮箱或密码错误"
            print("❌ 登录失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 步骤1: 发送密码重置验证码
    /// - Parameter email: 用户邮箱
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送密码重置邮件（会触发 Reset Password 邮件模板）
            try await supabase.auth.resetPasswordForEmail(email)

            otpSent = true
            errorMessage = nil
            print("✅ 密码重置验证码已发送到: \(email)")

        } catch {
            errorMessage = "发送重置验证码失败: \(error.localizedDescription)"
            print("❌ 发送密码重置验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 步骤2: 验证密码重置验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    /// ⚠️ 注意: type 必须是 .recovery（不是 .email）
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证密码重置 OTP（⚠️ 使用 .recovery 类型）
            let response = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery  // ⚠️ 重要：密码重置使用 .recovery 类型
            )

            // 验证成功后用户已登录，等待设置新密码
            currentUser = response.user
            otpVerified = true
            needsPasswordSetup = true

            print("✅ 重置验证码验证成功: \(response.user.email ?? "Unknown")")
            print("⚠️ 请设置新密码")

        } catch {
            errorMessage = "验证码错误或已过期: \(error.localizedDescription)"
            print("❌ 验证重置验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 步骤3: 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            let response = try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            // 密码重置成功
            currentUser = response.user
            needsPasswordSetup = false
            isAuthenticated = true

            print("✅ 密码重置成功: \(response.user.email ?? "Unknown")")

        } catch {
            errorMessage = "重置密码失败: \(error.localizedDescription)"
            print("❌ 重置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// 使用 Apple 登录
    /// TODO: 实现 Sign in with Apple
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil

        // TODO: 实现 Apple 登录逻辑
        // 1. 使用 AuthenticationServices 获取 Apple 凭证
        // 2. 调用 supabase.auth.signInWithIdToken(provider: .apple, idToken:)
        // 3. 更新 currentUser 和 isAuthenticated

        errorMessage = "Apple 登录功能开发中..."
        print("⚠️ TODO: 实现 Apple 登录")

        isLoading = false
    }

    /// 使用 Google 登录
    /// TODO: 实现 Sign in with Google
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        // TODO: 实现 Google 登录逻辑
        // 1. 使用 Google Sign-In SDK 获取凭证
        // 2. 调用 supabase.auth.signInWithIdToken(provider: .google, idToken:)
        // 3. 更新 currentUser 和 isAuthenticated

        errorMessage = "Google 登录功能开发中..."
        print("⚠️ TODO: 实现 Google 登录")

        isLoading = false
    }

    // MARK: - 其他认证方法

    /// 退出登录
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()

            // 清除所有状态
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false
            otpSent = false
            otpVerified = false

            print("✅ 已退出登录")

        } catch {
            errorMessage = "退出登录失败: \(error.localizedDescription)"
            print("❌ 退出登录失败: \(error)")
        }

        isLoading = false
    }

    /// 检查当前会话状态
    func checkSession() async {
        isLoading = true

        do {
            // 获取当前会话
            let session = try await supabase.auth.session

            if let user = session.user {
                // 会话有效，用户已登录
                currentUser = user
                isAuthenticated = true
                needsPasswordSetup = false

                print("✅ 会话有效: \(user.email ?? "Unknown")")
            } else {
                // 无会话，用户未登录
                currentUser = nil
                isAuthenticated = false

                print("ℹ️ 无有效会话")
            }

        } catch {
            // 会话无效或已过期
            currentUser = nil
            isAuthenticated = false

            print("⚠️ 会话检查失败或已过期: \(error)")
        }

        isLoading = false
    }

    // MARK: - 辅助方法

    /// 重置所有状态（用于清理错误或重新开始流程）
    func resetState() {
        errorMessage = nil
        otpSent = false
        otpVerified = false
        isLoading = false
    }

    /// 验证邮箱格式
    /// - Parameter email: 邮箱地址
    /// - Returns: 是否为有效邮箱
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    /// 验证密码强度
    /// - Parameter password: 密码
    /// - Returns: (是否有效, 错误提示)
    func validatePassword(_ password: String) -> (isValid: Bool, message: String?) {
        if password.count < 6 {
            return (false, "密码至少需要 6 个字符")
        }
        if password.count > 72 {
            return (false, "密码不能超过 72 个字符")
        }
        return (true, nil)
    }
}

// MARK: - Preview Helper

#if DEBUG
extension AuthManager {
    /// 创建用于预览的模拟实例
    static var preview: AuthManager {
        let manager = AuthManager()
        // 可以在这里设置模拟数据
        return manager
    }
}
#endif
