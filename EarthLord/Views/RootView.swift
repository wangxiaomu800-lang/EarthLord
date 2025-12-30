import SwiftUI

/// 根视图：控制启动页、认证页与主界面的切换
struct RootView: View {
    /// 认证管理器（共享实例）
    @StateObject private var authManager = AuthManager()

    /// 启动页是否完成
    @State private var splashFinished = false

    var body: some View {
        ZStack {
            if !splashFinished {
                // 阶段 1: 显示启动页（检查会话状态）
                SplashView(isFinished: $splashFinished)
                    .environmentObject(authManager)
                    .transition(.opacity)
            } else if !authManager.isAuthenticated {
                // 阶段 2: 未登录，显示认证页
                AuthView()
                    .environmentObject(authManager)
                    .transition(.opacity)
            } else {
                // 阶段 3: 已登录，显示主界面
                ContentView()
                    .environmentObject(authManager)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.5), value: authManager.isAuthenticated)
    }
}

#Preview {
    RootView()
}
