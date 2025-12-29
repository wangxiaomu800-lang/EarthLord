import SwiftUI

/// 根视图：控制启动页、认证页与主界面的切换
struct RootView: View {
    /// 启动页是否完成
    @State private var splashFinished = false

    /// 认证管理器（共享实例）
    @StateObject private var authManager = AuthManager()

    var body: some View {
        ZStack {
            if !splashFinished {
                // 显示启动页
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
            } else if !authManager.isAuthenticated {
                // 启动页完成但未登录，显示认证页
                AuthView()
                    .environmentObject(authManager)
                    .transition(.opacity)
            } else {
                // 已登录，显示主界面
                MainTabView()
                    .environmentObject(authManager)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .task {
            // 应用启动时检查会话状态
            if splashFinished {
                await authManager.checkSession()
            }
        }
    }
}

#Preview {
    RootView()
}
