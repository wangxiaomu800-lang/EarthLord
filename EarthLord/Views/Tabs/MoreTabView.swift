import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationView {
            List {
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
            .navigationTitle("更多")
        }
    }
}

#Preview {
    MoreTabView()
}
