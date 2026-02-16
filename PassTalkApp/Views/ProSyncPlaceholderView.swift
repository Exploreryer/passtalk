import SwiftUI

struct ProSyncPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("iCloud 同步（Pro）")
                .font(.title.bold())
            Text("当前版本暂未启用同步。")
            Text("未来你可以把本地数据安全同步到你的 iCloud。")
            Text("不需要注册 PassTalk 账号，也不需要 Sign in with Apple。")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .navigationTitle("iCloud 同步")
    }
}
