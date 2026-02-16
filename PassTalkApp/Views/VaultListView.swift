import SwiftUI
import UIKit

struct VaultListView: View {
    @ObservedObject var viewModel: VaultViewModel
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color(white: 0.96).ignoresSafeArea()

                VStack(spacing: 12) {
                    searchBar

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            tagChip(title: "全部", selected: viewModel.selectedTag == nil) {
                                viewModel.selectedTag = nil
                                viewModel.reload()
                            }
                            ForEach(PresetTag.allCases) { tag in
                                tagChip(title: tag.displayName, selected: viewModel.selectedTag == tag) {
                                    viewModel.selectedTag = tag
                                    viewModel.reload()
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if viewModel.entries.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "lock.slash")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("暂无条目")
                                .font(.headline)
                            Text("点击右上角 + 或通过聊天录入账号信息")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(viewModel.entries) { entry in
                                VaultEntryCard(
                                    entry: entry,
                                    onOpenDetail: {
                                        path.append(entry.recordUUID)
                                    },
                                    onCopyAccount: {
                                        UIPasteboard.general.string = entry.account
                                    },
                                    onCopyPassword: {
                                        UIPasteboard.general.string = entry.password
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing) {
                                    Button("删除", role: .destructive) {
                                        viewModel.delete(recordUUID: entry.recordUUID)
                                    }
                                    Button("编辑") {
                                        viewModel.editingEntry = entry
                                        viewModel.isPresentingEditor = true
                                    }
                                }
                                .contextMenu {
                                    Button("复制账号") {
                                        UIPasteboard.general.string = entry.account
                                    }
                                    Button("复制密码") {
                                        UIPasteboard.general.string = entry.password
                                    }
                                    Button("编辑") {
                                        viewModel.editingEntry = entry
                                        viewModel.isPresentingEditor = true
                                    }
                                    Button("删除", role: .destructive) {
                                        viewModel.delete(recordUUID: entry.recordUUID)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("密码本")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.editingEntry = nil
                        viewModel.isPresentingEditor = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.95))
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $viewModel.isPresentingEditor) {
                EntryEditorView(entry: viewModel.editingEntry) { platform, account, password, note, primary, secondary in
                    viewModel.save(platform: platform, account: account, password: password, note: note, primaryTag: primary, secondaryTag: secondary)
                }
            }
            .navigationDestination(for: String.self) { recordUUID in
                if let entry = viewModel.entries.first(where: { $0.recordUUID == recordUUID }) {
                    EntryDetailView(
                        entry: entry,
                        onEdit: {
                            viewModel.editingEntry = entry
                            viewModel.isPresentingEditor = true
                        },
                        onDelete: {
                            viewModel.delete(recordUUID: entry.recordUUID)
                        }
                    )
                } else {
                    Text("条目不存在")
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear { viewModel.reload() }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索...", text: $viewModel.keyword)
                .onChange(of: viewModel.keyword) { _ in
                    viewModel.reload()
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tagChip(title: String, selected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.black : Color.white)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct VaultEntryCard: View {
    let entry: PasswordEntry
    let onOpenDetail: () -> Void
    let onCopyAccount: () -> Void
    let onCopyPassword: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Text(String(entry.platform.prefix(1)).uppercased())
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.platform)
                        .font(.system(size: 31 / 2, weight: .bold))
                    Text(entry.primaryTag.displayName)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)

            HStack {
                Text(entry.account)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                Spacer()
                iconButton("doc.on.doc", action: onCopyAccount)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 14)

            HStack {
                Text(String(repeating: "•", count: max(8, min(entry.password.count, 10))))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                icon("eye")
                iconButton("doc.on.doc", action: onCopyPassword)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            onOpenDetail()
        }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary.opacity(0.72))
            .frame(width: 22, height: 22)
    }

    private func iconButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.82))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
    }
}
