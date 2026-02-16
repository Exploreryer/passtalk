import SwiftUI
import UIKit

struct EntryDetailView: View {
    let entry: PasswordEntry
    let onEdit: () -> Void
    @State private var isPasswordVisible = false

    var body: some View {
        ZStack {
            Color(white: 0.96).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    credentialCard
                    metaCard
                }
                .padding(16)
            }
        }
        .navigationTitle("详情")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.16))
                .frame(width: 52, height: 52)
                .overlay {
                    Text(String(entry.platform.prefix(1)).uppercased())
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.platform)
                    .font(.title3.bold())
                Text("更新于 \(PassTalkDateFormatter.short.string(from: entry.updatedAt))")
                    .font(.footnote)
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
                value: isPasswordVisible ? entry.password : String(repeating: "•", count: min(entry.password.count, 10)),
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

    private var metaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("同步信息")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("v\(entry.syncVersion) · \(entry.syncState.rawValue)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var tagChips: some View {
        HStack(spacing: 8) {
            chip(entry.primaryTag.displayName)
            if let secondary = entry.secondaryTag {
                chip(secondary.displayName)
            }
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.gray.opacity(0.12))
            .clipShape(Capsule())
    }

    private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Color.gray.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
