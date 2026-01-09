import SwiftUI

struct MoreTabView: View {
    // MARK: - 状态

    /// 是否显示探索结果弹窗
    @State private var showExplorationResult = false

    var body: some View {
        NavigationView {
            List {
                // MARK: - 探索模块测试
                Section(header: Text("探索模块（测试）")) {
                    // POI 列表
                    NavigationLink(destination: POIListView()) {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("附近地点")
                                    .font(.headline)
                                Text("查看和搜索附近的兴趣点")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    // 背包
                    NavigationLink(destination: BackpackView()) {
                        HStack {
                            Image(systemName: "bag.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("背包")
                                    .font(.headline)
                                Text("管理你收集的物资")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    // 探索结果（弹窗测试）
                    Button(action: { showExplorationResult = true }) {
                        HStack {
                            Image(systemName: "flag.checkered")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading) {
                                Text("探索结果")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("测试探索完成弹窗")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                // MARK: - 开发测试
                Section(header: Text("开发工具")) {
                    NavigationLink(destination: TestMenuView()) {
                        HStack {
                            Image(systemName: "hammer.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("开发测试")
                                    .font(.headline)
                                Text("Supabase 和圈地功能测试")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("更多")
            .sheet(isPresented: $showExplorationResult) {
                ExplorationResultView(result: MockExplorationData.explorationResult)
            }
        }
    }
}

#Preview {
    MoreTabView()
}
