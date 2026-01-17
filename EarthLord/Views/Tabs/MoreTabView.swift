import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationView {
            List {
                // MARK: - 开发测试
                Section(header: Text(NSLocalizedString("开发工具", comment: "Development tools"))) {
                    NavigationLink(destination: TestMenuView()) {
                        HStack {
                            Image(systemName: "hammer.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text(NSLocalizedString("开发测试", comment: "Development test"))
                                    .font(.headline)
                                Text(NSLocalizedString("数据库和圈地功能测试", comment: "Database and territory claiming test"))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("更多", comment: "More"))
        }
    }
}

#Preview {
    MoreTabView()
}
