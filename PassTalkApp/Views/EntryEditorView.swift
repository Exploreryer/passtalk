import SwiftUI

struct EntryEditorView: View {
    let entry: PasswordEntry?
    let onSave: (String, String, String, String, PresetTag, PresetTag?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var platform: String = ""
    @State private var account: String = ""
    @State private var password: String = ""
    @State private var note: String = ""
    @State private var primaryTag: PresetTag = .other
    @State private var secondaryTag: PresetTag?

    var body: some View {
        NavigationStack {
            Form {
                TextField("平台", text: $platform)
                TextField("账号", text: $account)
                TextField("密码", text: $password)
                TextField("备注", text: $note, axis: .vertical)
                Picker("主标签", selection: $primaryTag) {
                    ForEach(PresetTag.allCases) { tag in
                        Text(tag.displayName).tag(tag)
                    }
                }

                Picker("副标签（可选）", selection: $secondaryTag) {
                    Text("无").tag(nil as PresetTag?)
                    ForEach(PresetTag.allCases) { tag in
                        Text(tag.displayName).tag(Optional(tag))
                    }
                }
            }
            .navigationTitle(entry == nil ? "新建条目" : "编辑条目")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        let normalizedSecondary = (secondaryTag == primaryTag) ? nil : secondaryTag
                        onSave(platform, account, password, note, primaryTag, normalizedSecondary)
                        dismiss()
                    }
                    .disabled(platform.isEmpty || account.isEmpty || password.isEmpty)
                }
            }
            .onAppear {
                if let entry {
                    platform = entry.platform
                    account = entry.account
                    password = entry.password
                    note = entry.note
                    primaryTag = entry.primaryTag
                    secondaryTag = entry.secondaryTag
                }
            }
            .onChange(of: primaryTag) { newValue in
                if secondaryTag == newValue {
                    secondaryTag = nil
                }
            }
        }
    }
}
