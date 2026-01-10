import SwiftUI
import UIKit

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MapTabView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("地图")
                }
                .tag(0)

            TerritoryTabView()
                .tabItem {
                    Image(systemName: "flag.fill")
                    Text("领地")
                }
                .tag(1)

            ResourcesTabView()
                .tabItem {
                    Image(systemName: "cube.box.fill")
                    Text("资源")
                }
                .tag(2)

            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("个人")
                }
                .tag(3)

            MoreTabView()
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("更多")
                }
                .tag(4)
        }
        .tint(Color(red: 1.0, green: 0.42, blue: 0.21)) // 橙色主题
        .onAppear {
            // 设置TabBar的背景为不透明的深色
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)

            // 设置图标和文字颜色
            let itemAppearance = UITabBarItemAppearance()
            itemAppearance.normal.iconColor = UIColor.gray
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
            itemAppearance.selected.iconColor = UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1.0)
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1.0)]

            appearance.stackedLayoutAppearance = itemAppearance
            appearance.inlineLayoutAppearance = itemAppearance
            appearance.compactInlineLayoutAppearance = itemAppearance

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    MainTabView()
}
