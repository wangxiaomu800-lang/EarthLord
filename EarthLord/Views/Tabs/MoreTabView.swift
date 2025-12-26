import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: SupabaseTestView()) {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Supabase 连接测试")
                                .font(.headline)
                            Text("测试数据库连接状态")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("更多")
        }
    }
}

#Preview {
    MoreTabView()
}
