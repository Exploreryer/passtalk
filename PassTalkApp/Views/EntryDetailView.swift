import SwiftUI
import UIKit

struct EntryDetailView: View {
    let entry: PasswordEntry
    let onEdit: () -> Void
    var onDelete: (() -> Void)? = nil
    @State private var isPasswordVisible = false
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(white: 0.96).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    credentialCard
                }
                .padding(16)
            }
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("返回")
                            .font(.callout)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 14) {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    if onDelete != nil {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.secondary.opacity(0.55))
                        }
                    }
                }
            }
        }
        .alert("确认删除此条目？", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                onDelete?()
                dismiss()
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.gray.opacity(0.16))
                .frame(width: 52, height: 52)
                .overlay {
                    Text(String(entry.platform.prefix(1)).uppercased())
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.platform)
                    .font(.title3.weight(.bold))
                Text("\(entry.primaryTag.displayName)  ·  \(PassTalkDateFormatter.short.string(from: entry.updatedAt)) 更新")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var credentialCard: some View {
        VStack(spacing: 0) {
            detailRow(
                title: "账号",
                value: entry.account,
                actions: {
                    iconButton("doc.on.doc") {
                        UIPasteboard.general.string = entry.account
                    }
                }
            )
            Divider().padding(.leading, 16)
            detailRow(
                title: "密码",
                value: isPasswordVisible ? entry.password : String(repeating: "•", count: max(8, min(entry.password.count, 10))),
                actions: {
                    iconButton(isPasswordVisible ? "eye.slash" : "eye") {
                        isPasswordVisible.toggle()
                    }
                    iconButton("doc.on.doc") {
                        UIPasteboard.general.string = entry.password
                    }
                }
            )
            Divider().padding(.leading, 16)
            VStack(alignment: .leading, spacing: 8) {
                Text("标签")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                tagChips
            }
            .padding(16)
            if !entry.note.isEmpty {
                Divider().padding(.leading, 16)
                VStack(alignment: .leading, spacing: 8) {
                    Text("备注")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.note)
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var tagChips: some View {
        HStack(spacing: 8) {
            chip(entry.primaryTag.displayName)
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.12))
            .clipShape(Capsule())
    }

    private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.85))
                .frame(width: 24, height: 24)
        }
    }

    private func detailRow<Actions: View>(
        title: String,
        value: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
            }
            Spacer()
            HStack(spacing: 8) {
                actions()
            }
        }
        .padding(16)
    }
}
