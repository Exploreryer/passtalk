import SwiftUI
import UIKit

struct VaultListView: View {
    @ObservedObject var viewModel: VaultViewModel

    var body: some View {
        NavigationStack {
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
                                NavigationLink {
                                    EntryDetailView(entry: entry, onEdit: {
                                        viewModel.editingEntry = entry
                                        viewModel.isPresentingEditor = true
                                    })
                                } label: {
                                    VaultEntryCard(entry: entry)
                                }
                                .buttonStyle(.plain)
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
                    }
                }
            }
            .sheet(isPresented: $viewModel.isPresentingEditor) {
                EntryEditorView(entry: viewModel.editingEntry) { platform, account, password, note, primary, secondary in
                    viewModel.save(platform: platform, account: account, password: password, note: note, primaryTag: primary, secondaryTag: secondary)
                }
            }
            .onAppear { viewModel.reload() }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索平台、账号、备注、标签", text: $viewModel.keyword)
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 34, height: 34)
                .overlay {
                    Text(String(entry.platform.prefix(1)).uppercased())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.platform)
                    .font(.headline)
                Text(entry.account)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(String(repeating: "•", count: min(entry.password.count, 10)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
