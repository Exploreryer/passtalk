import SwiftUI

struct EntryEditorView: View {
    let entry: PasswordEntry?
    let onSave: (String, String, String, String, PresetTag, PresetTag?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var platform: String = ""
    @State private var account: String = ""
    @State private var password: String = ""
    @State private var note: String = ""
    @State private var primaryTag: PresetTag = .work
    @State private var secondaryTag: PresetTag?
    @State private var isPasswordVisible = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.96).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        editorCard {
                            field(title: "平台") {
                                TextField("例如：Figma", text: $platform)
                            }
                            divider
                            field(title: "账号") {
                                TextField("例如：design@company.com", text: $account)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            divider
                            field(title: "密码") {
                                HStack(spacing: 8) {
                                    Group {
                                        if isPasswordVisible {
                                            TextField("请输入密码", text: $password)
                                        } else {
                                            SecureField("请输入密码", text: $password)
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
                        let normalizedSecondary = (secondaryTag == primaryTag) ? nil : secondaryTag
                        onSave(platform, account, password, note, primaryTag, normalizedSecondary)
                        dismiss()
                    }
                    label: {
                        Text("保存")
                            .font(.system(size: 15, weight: .semibold))
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
                .font(.system(size: 16))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Divider().padding(.leading, 14)
    }

    private var tagSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            Menu {
                Button("无副标签") {
                    secondaryTag = nil
                }
                ForEach(PresetTag.allCases) { tag in
                    Button(tag.displayName) {
                        secondaryTag = (tag == primaryTag) ? nil : tag
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(secondaryTag?.displayName ?? "添加副标签")
                        .font(.system(size: 13))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.gray.opacity(0.12))
                .clipShape(Capsule())
            }
        }
    }

    private func tagChip(title: String, selected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(selected ? Color(red: 0.20, green: 0.20, blue: 0.22) : Color.gray.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
