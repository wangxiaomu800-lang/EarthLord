import SwiftUI

/// 认证页面 - 登录/注册/找回密码
struct AuthView: View {
    // MARK: - State
    @EnvironmentObject var authManager: AuthManager

    /// 当前选中的Tab（登录/注册）
    @State private var selectedTab: AuthTab = .login

    /// 登录表单
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    /// 注册表单
    @State private var registerEmail = ""
    @State private var registerOTP = ""
    @State private var registerPassword = ""
    @State private var registerConfirmPassword = ""

    /// 找回密码表单
    @State private var resetEmail = ""
    @State private var resetOTP = ""
    @State private var resetPassword = ""
    @State private var resetConfirmPassword = ""

    /// 是否显示忘记密码弹窗
    @State private var showResetPasswordSheet = false

    /// 找回密码流程步骤（1=发送验证码, 2=验证, 3=设置新密码）
    @State private var resetStep = 1

    /// 验证码倒计时（秒）
    @State private var otpCountdown = 0
    @State private var resetOtpCountdown = 0

    /// 倒计时定时器
    @State private var otpTimer: Timer? = nil
    @State private var resetOtpTimer: Timer? = nil

    // MARK: - Tab枚举
    enum AuthTab {
        case login
        case register
    }

    var body: some View {
        ZStack {
            // MARK: - 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.18),
                    Color(red: 0.09, green: 0.13, blue: 0.24),
                    Color(red: 0.06, green: 0.06, blue: 0.10)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Logo 和标题
                    logoSection

                    // MARK: - Tab 切换
                    tabSwitcher

                    // MARK: - 表单内容
                    if selectedTab == .login {
                        loginForm
                    } else {
                        registerForm
                    }

                    // MARK: - 第三方登录
                    thirdPartyLoginSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 40)
            }

            // MARK: - 加载指示器
            if authManager.isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .sheet(isPresented: $showResetPasswordSheet) {
            resetPasswordSheet
        }
    }

    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 16) {
            // Logo 圆形背景
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primary.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10)

                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            // 标题
            Text(NSLocalizedString("地球新主", comment: "Earth Lord"))
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("EARTH LORD")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .tracking(3)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Tab Switcher
    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            // 登录 Tab
            Button(action: { selectedTab = .login }) {
                Text("登录")
                    .font(.headline)
                    .foregroundColor(selectedTab == .login ? .white : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == .login
                            ? ApocalypseTheme.primary
                            : Color.clear
                    )
            }

            // 注册 Tab
            Button(action: { selectedTab = .register }) {
                Text("注册")
                    .font(.headline)
                    .foregroundColor(selectedTab == .register ? .white : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == .register
                            ? ApocalypseTheme.primary
                            : Color.clear
                    )
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(8)
    }

    // MARK: - 登录表单
    private var loginForm: some View {
        VStack(spacing: 16) {
            // 邮箱输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("邮箱")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                TextField("请输入邮箱", text: $loginEmail)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
            }

            // 密码输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("密码")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                SecureField("请输入密码", text: $loginPassword)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.password)
            }

            // 错误提示
            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 登录按钮
            Button(action: handleLogin) {
                Text("登录")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(loginEmail.isEmpty || loginPassword.isEmpty)
            .opacity(loginEmail.isEmpty || loginPassword.isEmpty ? 0.5 : 1.0)

            // 忘记密码链接
            Button(action: { showResetPasswordSheet = true }) {
                Text("忘记密码？")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.info)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - 注册表单
    private var registerForm: some View {
        VStack(spacing: 16) {
            // 根据流程状态显示不同步骤
            if !authManager.otpVerified {
                // 步骤1和2：发送验证码 → 验证
                registerStepOneAndTwo
            } else if authManager.needsPasswordSetup {
                // 步骤3：设置密码
                registerStepThree
            }
        }
        .padding(.top, 20)
    }

    // MARK: - 注册步骤1和2
    private var registerStepOneAndTwo: some View {
        VStack(spacing: 16) {
            // 邮箱输入框
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("邮箱")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    // 如果已发送验证码，显示"修改邮箱"按钮
                    if authManager.otpSent {
                        Button("修改邮箱") {
                            // 重置注册状态
                            authManager.resetState()
                            registerOTP = ""
                            otpCountdown = 0
                            otpTimer?.invalidate()
                        }
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.info)
                    }
                }

                TextField("请输入邮箱", text: $registerEmail)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .onChange(of: registerEmail) { _, _ in
                        // 邮箱修改后，清除错误信息
                        authManager.errorMessage = nil
                    }
            }

            // 发送验证码按钮
            if !authManager.otpSent {
                Button(action: handleSendRegisterOTP) {
                    Text("发送验证码")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                }
                .disabled(registerEmail.isEmpty)
                .opacity(registerEmail.isEmpty ? 0.5 : 1.0)
            }

            // 验证码输入（发送后显示）
            if authManager.otpSent {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("验证码")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Spacer()

                        if otpCountdown > 0 {
                            Text("\(otpCountdown)秒后重发")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.textMuted)
                        } else {
                            Button("重新发送") {
                                handleSendRegisterOTP()
                            }
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.info)
                        }
                    }

                    TextField("请输入6位验证码", text: $registerOTP)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                }

                // 验证按钮
                Button(action: handleVerifyRegisterOTP) {
                    Text("验证")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                }
                .disabled(registerOTP.count != 6)
                .opacity(registerOTP.count != 6 ? 0.5 : 1.0)
            }

            // 错误提示
            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - 注册步骤3：设置密码
    private var registerStepThree: some View {
        VStack(spacing: 16) {
            // 提示信息
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(ApocalypseTheme.success)
                Text("验证成功！请设置密码完成注册")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(ApocalypseTheme.success.opacity(0.1))
            .cornerRadius(8)

            // 密码输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("设置密码")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                SecureField("请输入密码（至少6位）", text: $registerPassword)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.newPassword)
            }

            // 确认密码输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("确认密码")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                SecureField("请再次输入密码", text: $registerConfirmPassword)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.newPassword)
            }

            // 密码强度提示
            if !registerPassword.isEmpty {
                let validation = authManager.validatePassword(registerPassword)
                if !validation.isValid, let message = validation.message {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.warning)
                }
            }

            // 密码不匹配提示
            if !registerConfirmPassword.isEmpty && registerPassword != registerConfirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            // 错误提示
            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            // 完成注册按钮
            Button(action: handleCompleteRegistration) {
                Text("完成注册")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(!canCompleteRegistration)
            .opacity(canCompleteRegistration ? 1.0 : 0.5)
        }
    }

    // MARK: - 第三方登录
    private var thirdPartyLoginSection: some View {
        VStack(spacing: 16) {
            // 分隔线
            HStack {
                Rectangle()
                    .fill(ApocalypseTheme.textMuted)
                    .frame(height: 1)

                Text("或者使用以下方式登录")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .padding(.horizontal, 8)

                Rectangle()
                    .fill(ApocalypseTheme.textMuted)
                    .frame(height: 1)
            }
            .padding(.top, 20)

            // Apple 登录按钮
            Button(action: handleAppleLogin) {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                    Text("使用 Apple 登录")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .cornerRadius(12)
            }

            // Google 登录按钮
            Button(action: handleGoogleLogin) {
                HStack {
                    Image(systemName: "globe")
                        .font(.title3)
                    Text("使用 Google 登录")
                        .font(.headline)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - 找回密码弹窗
    private var resetPasswordSheet: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 步骤指示器
                        stepIndicator(currentStep: resetStep, totalSteps: 3)

                        // 根据步骤显示不同内容
                        switch resetStep {
                        case 1:
                            resetStepOne
                        case 2:
                            resetStepTwo
                        case 3:
                            resetStepThree
                        default:
                            EmptyView()
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        showResetPasswordSheet = false
                        resetResetPasswordFlow()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 找回密码步骤1
    private var resetStepOne: some View {
        VStack(spacing: 16) {
            // 邮箱输入
            VStack(alignment: .leading, spacing: 8) {
                Text("邮箱")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                TextField("请输入注册邮箱", text: $resetEmail)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
            }

            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            Button(action: handleSendResetOTP) {
                Text("发送验证码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(resetEmail.isEmpty || authManager.isLoading)
            .opacity(resetEmail.isEmpty ? 0.5 : 1.0)
        }
    }

    // MARK: - 找回密码步骤2
    private var resetStepTwo: some View {
        VStack(spacing: 16) {
            // 验证码输入
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("验证码")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    if resetOtpCountdown > 0 {
                        Text("\(resetOtpCountdown)秒后重发")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                    } else {
                        Button("重新发送") {
                            resetStep = 1
                        }
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.info)
                    }
                }

                TextField("请输入6位验证码", text: $resetOTP)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
            }

            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            Button(action: handleVerifyResetOTP) {
                Text("验证")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(resetOTP.count != 6 || authManager.isLoading)
            .opacity(resetOTP.count != 6 ? 0.5 : 1.0)
        }
    }

    // MARK: - 找回密码步骤3
    private var resetStepThree: some View {
        VStack(spacing: 16) {
            // 成功提示
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(ApocalypseTheme.success)
                Text("验证成功！请设置新密码")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(ApocalypseTheme.success.opacity(0.1))
            .cornerRadius(8)

            // 新密码输入
            VStack(alignment: .leading, spacing: 8) {
                Text("新密码")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                SecureField("请输入新密码（至少6位）", text: $resetPassword)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.newPassword)
            }

            // 确认密码
            VStack(alignment: .leading, spacing: 8) {
                Text("确认密码")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                SecureField("请再次输入新密码", text: $resetConfirmPassword)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.newPassword)
            }

            // 密码不匹配提示
            if !resetConfirmPassword.isEmpty && resetPassword != resetConfirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            Button(action: handleResetPassword) {
                Text("重置密码")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(!canResetPassword || authManager.isLoading)
            .opacity(canResetPassword ? 1.0 : 0.5)
        }
    }

    // MARK: - 步骤指示器
    private func stepIndicator(currentStep: Int, totalSteps: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.bottom, 10)
    }

    // MARK: - Action Handlers

    /// 处理登录
    private func handleLogin() {
        Task {
            await authManager.signIn(email: loginEmail, password: loginPassword)
        }
    }

    /// 发送注册验证码
    private func handleSendRegisterOTP() {
        guard authManager.isValidEmail(registerEmail) else {
            authManager.errorMessage = "请输入有效的邮箱地址"
            return
        }

        Task {
            await authManager.sendRegisterOTP(email: registerEmail)
            if authManager.otpSent {
                startOTPCountdown()
            }
        }
    }

    /// 验证注册验证码
    private func handleVerifyRegisterOTP() {
        Task {
            await authManager.verifyRegisterOTP(email: registerEmail, code: registerOTP)
        }
    }

    /// 完成注册
    private func handleCompleteRegistration() {
        Task {
            await authManager.completeRegistration(password: registerPassword)
        }
    }

    /// 发送重置验证码
    private func handleSendResetOTP() {
        Task {
            await authManager.sendResetOTP(email: resetEmail)
            if authManager.otpSent {
                resetStep = 2
                startResetOTPCountdown()
            }
        }
    }

    /// 验证重置验证码
    private func handleVerifyResetOTP() {
        Task {
            await authManager.verifyResetOTP(email: resetEmail, code: resetOTP)
            if authManager.otpVerified {
                resetStep = 3
            }
        }
    }

    /// 重置密码
    private func handleResetPassword() {
        Task {
            await authManager.resetPassword(newPassword: resetPassword)
            if authManager.isAuthenticated {
                showResetPasswordSheet = false
                resetResetPasswordFlow()
            }
        }
    }

    /// Apple 登录（占位）
    private func handleAppleLogin() {
        // TODO: 实现 Apple 登录
        authManager.errorMessage = "Apple 登录即将开放"
    }

    /// Google 登录
    private func handleGoogleLogin() {
        print("🔵 用户点击 Google 登录按钮")
        Task {
            await authManager.signInWithGoogle()
        }
    }

    // MARK: - Helper Functions

    /// 是否可以完成注册
    private var canCompleteRegistration: Bool {
        let validation = authManager.validatePassword(registerPassword)
        return validation.isValid &&
               registerPassword == registerConfirmPassword &&
               !registerPassword.isEmpty
    }

    /// 是否可以重置密码
    private var canResetPassword: Bool {
        let validation = authManager.validatePassword(resetPassword)
        return validation.isValid &&
               resetPassword == resetConfirmPassword &&
               !resetPassword.isEmpty
    }

    /// 启动注册验证码倒计时
    private func startOTPCountdown() {
        otpCountdown = 60
        otpTimer?.invalidate()
        otpTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if otpCountdown > 0 {
                otpCountdown -= 1
            } else {
                otpTimer?.invalidate()
            }
        }
    }

    /// 启动重置验证码倒计时
    private func startResetOTPCountdown() {
        resetOtpCountdown = 60
        resetOtpTimer?.invalidate()
        resetOtpTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resetOtpCountdown > 0 {
                resetOtpCountdown -= 1
            } else {
                resetOtpTimer?.invalidate()
            }
        }
    }

    /// 重置找回密码流程
    private func resetResetPasswordFlow() {
        resetStep = 1
        resetEmail = ""
        resetOTP = ""
        resetPassword = ""
        resetConfirmPassword = ""
        resetOtpTimer?.invalidate()
        resetOtpCountdown = 0
        authManager.resetState()
    }
}

// MARK: - 自定义文本框样式
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .foregroundColor(ApocalypseTheme.textPrimary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Preview
#Preview {
    AuthView()
        .environmentObject(AuthManager())
}
