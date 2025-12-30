import SwiftUI
import Supabase
import Combine

/// 认证管理器 - 管理用户注册、登录、密码重置等认证流程
@MainActor
class AuthManager: ObservableObject {

    // MARK: - Published Properties (发布属性)

    /// 用户是否已完全认证（已登录且完成所有必要步骤）
    /// ⚠️ 重要：默认为 false，只有在会话验证成功后才设置为 true
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

    /// 认证状态监听任务
    private var authStateTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        self.supabase = SupabaseConfig.shared
        startAuthStateListener()
    }

    // 用于测试的自定义初始化方法
    init(supabase: SupabaseClient) {
        self.supabase = supabase
        startAuthStateListener()
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - 注册流程

    /// 步骤1: 发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 先尝试检查用户是否已存在（shouldCreateUser: false）
            // 如果用户存在，会成功发送 OTP（但这不是我们想要的）
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: false
            )

            // 如果执行到这里，说明用户已存在
            errorMessage = "该邮箱已注册，请前往登录页面"
            print("❌ 注册失败: 邮箱 \(email) 已被注册")

        } catch {
            // 如果失败，说明用户不存在，可以注册
            // 尝试发送注册 OTP（shouldCreateUser: true）
            print("ℹ️ 用户不存在，准备发送注册验证码")

            do {
                try await supabase.auth.signInWithOTP(
                    email: email,
                    shouldCreateUser: true
                )

                otpSent = true
                errorMessage = nil
                print("✅ 注册验证码已发送到: \(email)")

            } catch let createError {
                errorMessage = "发送验证码失败: \(createError.localizedDescription)"
                print("❌ 发送注册验证码失败: \(createError)")
            }
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
            let user = try await supabase.auth.update(
                user: UserAttributes(password: password)
            )

            // 密码设置成功，注册流程完成
            currentUser = user
            needsPasswordSetup = false
            isAuthenticated = true  // ✅ 注册完成，设置为已认证

            print("✅ 注册完成: \(user.email ?? "Unknown")")

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
            let user = try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            // 密码重置成功
            currentUser = user
            needsPasswordSetup = false
            isAuthenticated = true

            print("✅ 密码重置成功: \(user.email ?? "Unknown")")

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
    /// - Parameter scope: 退出范围（默认为 global，清除所有设备的会话）
    func signOut(scope: SignOutScope = .global) async {
        isLoading = true
        errorMessage = nil

        print("🚪 开始退出登录...")

        do {
            // 调用 Supabase 退出登录
            try await supabase.auth.signOut(scope: scope)

            // 清除所有本地状态
            await MainActor.run {
                currentUser = nil
                isAuthenticated = false
                needsPasswordSetup = false
                otpSent = false
                otpVerified = false
            }

            print("✅ 退出登录成功")
            print("📱 已清除本地会话状态")

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

            // 检查会话是否过期（启用 emitLocalSessionAsInitialSession 后需要额外检查）
            if session.isExpired {
                // 会话已过期，清除状态并自动跳转登录页
                await handleSessionExpired()
            } else {
                // 会话有效，用户已登录
                currentUser = session.user
                isAuthenticated = true
                needsPasswordSetup = false
                print("✅ 会话有效: \(session.user.email ?? "Unknown")")

                let expiresAt = Date(timeIntervalSince1970: session.expiresAt)
                print("🔐 会话过期时间: \(expiresAt)")
            }

        } catch {
            // 会话无效或已过期
            await handleSessionExpired()
            print("⚠️ 会话检查失败或已过期: \(error)")
        }

        isLoading = false
    }

    /// 处理会话过期
    private func handleSessionExpired() async {
        await MainActor.run {
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false
            otpSent = false
            otpVerified = false
            errorMessage = "会话已过期，请重新登录"
        }

        print("⏰ 会话已过期，用户需要重新登录")
    }

    // MARK: - 认证状态监听

    /// 启动认证状态监听
    /// 监听 Supabase Auth 状态变化，自动更新 isAuthenticated
    private func startAuthStateListener() {
        authStateTask = Task { @MainActor in
            for await (event, session) in supabase.auth.authStateChanges {
                handleAuthStateChange(event: event, session: session)
            }
        }
    }

    /// 处理认证状态变化
    /// - Parameters:
    ///   - event: 认证事件类型
    ///   - session: 会话信息（可选）
    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) {
        print("🔐 认证状态变化: \(event)")

        switch event {
        case .initialSession, .signedIn, .tokenRefreshed:
            // 用户已登录或会话刷新
            if let session = session {
                if !session.isExpired {
                    currentUser = session.user

                    // ⚠️ 重要：如果正在注册流程中（需要设置密码），不要自动认证
                    if needsPasswordSetup {
                        isAuthenticated = false
                        print("⚠️ 用户已登录但需要设置密码（注册流程）")
                    } else {
                        isAuthenticated = true
                        print("✅ 用户已登录: \(session.user.email ?? "Unknown")")

                        // 显示会话有效期（expiresAt 是时间戳）
                        let expiresAt = Date(timeIntervalSince1970: session.expiresAt)
                        let timeRemaining = expiresAt.timeIntervalSinceNow
                        if timeRemaining > 0 {
                            print("⏱️  会话有效期剩余: \(Int(timeRemaining / 60)) 分钟")
                        } else {
                            print("⚠️ 会话即将过期或已过期")
                        }
                    }
                } else {
                    // 会话已过期，触发过期处理
                    print("⏰ 检测到会话已过期，自动退出登录")
                    Task {
                        await handleSessionExpired()
                    }
                }
            } else {
                // 没有会话，清除状态
                currentUser = nil
                isAuthenticated = false
                print("⚠️ 无会话信息")
            }

        case .signedOut:
            // 用户已登出
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false
            otpSent = false
            otpVerified = false
            print("👋 用户已登出")

        case .userUpdated:
            // 用户信息更新
            if let session = session {
                currentUser = session.user
                print("📝 用户信息已更新")
            }

        case .userDeleted:
            // 用户被删除
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false
            otpSent = false
            otpVerified = false
            print("🗑️ 用户已删除")

        case .mfaChallengeVerified:
            // MFA 验证（暂不处理）
            print("🔒 MFA 验证完成")

        case .passwordRecovery:
            // 密码恢复流程：用户已验证 OTP，但需要设置新密码
            if let session = session {
                currentUser = session.user
                needsPasswordSetup = true
                isAuthenticated = false  // ⚠️ 重要：不要自动认证，等待设置新密码
                print("🔑 密码恢复流程：等待设置新密码")
            } else {
                print("⚠️ 密码恢复流程但无会话信息")
            }

        @unknown default:
            print("❓ 未知认证事件: \(event)")
        }
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
