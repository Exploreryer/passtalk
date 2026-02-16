import SwiftUI

struct EntryEditorView: View {
    let entry: PasswordEntry?
    let onSave: (String, String, String, String, PresetTag) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var platform: String = ""
    @State private var account: String = ""
    @State private var password: String = ""
    @State private var note: String = ""
    @State private var primaryTag: PresetTag = .work
    @State private var isPasswordVisible = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.96).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        editorCard {
                            field(title: "平台") {
                                TextField("", text: $platform, prompt: Text("例如：Figma").foregroundColor(.secondary))
                                    .foregroundStyle(.primary)
                            }
                            divider
                            field(title: "账号") {
                                TextField("", text: $account, prompt: Text("例如：design@company.com").foregroundColor(.secondary))
                                    .foregroundStyle(.primary)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            divider
                            field(title: "密码") {
                                HStack(spacing: 8) {
                                    Group {
                                        if isPasswordVisible {
                                            TextField("", text: $password, prompt: Text("请输入密码").foregroundColor(.secondary))
                                                .foregroundStyle(.primary)
                                        } else {
                                            SecureField("请输入密码", text: $password)
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()

                                    Button {
                                        isPasswordVisible.toggle()
                                    } label: {
                                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            divider
                            field(title: "标签") {
                                tagSelector
                            }
                            divider
                            field(title: "备注") {
                                ZStack(alignment: .topLeading) {
                                    if note.isEmpty {
                                        Text("可选，支持多行备注")
                                            .foregroundStyle(.secondary.opacity(0.7))
                                            .padding(.top, 8)
                                            .padding(.leading, 4)
                                    }
                                    TextEditor(text: $note)
                                        .frame(minHeight: 92)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(entry == nil ? "新建条目" : "编辑条目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onSave(platform, account, password, note, primaryTag)
                        dismiss()
                    }
                    label: {
                        Text("保存")
                            .font(.headline)
                            .foregroundStyle(Color.orange)
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
                }
            }
            .tint(.primary)
        }
    }

    @ViewBuilder
    private func editorCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
                .font(.body)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Divider().padding(.leading, 14)
    }

    private var tagSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PresetTag.allCases) { tag in
                    tagChip(
                        title: tag.displayName,
                        selected: primaryTag == tag
                    ) {
                        primaryTag = tag
                    }
                }
            }
        }
    }

    private func tagChip(title: String, selected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(selected ? Color(red: 0.20, green: 0.20, blue: 0.22) : Color.gray.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
