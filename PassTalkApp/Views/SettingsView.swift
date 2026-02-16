import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let importService: ImportServiceProtocol
    let exportService: ExportServiceProtocol
    let onReplayOnboarding: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showImporter = false
    @State private var selectedImportFormat: ImportFormat = .csv
    @State private var showExporter = false
    @State private var exportedDocument: PassTalkDocument?
    @State private var showImportFormatDialog = false
    @State private var showExportFormatDialog = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.96).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        settingsGroup {
                            NavigationLink {
                                HowToUseView(onReplayOnboarding: {
                                    dismiss()
                                    DispatchQueue.main.async {
                                        onReplayOnboarding()
                                    }
                                })
                            } label: {
                                SettingsRow(icon: "book.closed", title: "如何使用")
                            }

                            NavigationLink {
                                AboutPassTalkView()
                            } label: {
                                SettingsRow(icon: "info.circle", title: "关于 PassTalk")
                            }

                            NavigationLink {
                                PrivacySecurityView(
                                    viewModel: viewModel,
                                    endpoint: $viewModel.endpoint,
                                    model: $viewModel.model,
                                    systemPrompt: $viewModel.systemPrompt,
                                    apiKey: $viewModel.apiKey,
                                    onSave: { viewModel.saveAPISettings() }
                                )
                            } label: {
                                SettingsRow(icon: "shield", title: "隐私与安全")
                            }
                        }

                        settingsGroup {
                            Button {
                                showImportFormatDialog = true
                            } label: {
                                SettingsRow(icon: "square.and.arrow.down", title: "导入数据")
                            }
                            .buttonStyle(.plain)

                            Button {
                                showExportFormatDialog = true
                            } label: {
                                SettingsRow(icon: "square.and.arrow.up", title: "导出数据")
                            }
                            .buttonStyle(.plain)
                        }

                        settingsGroup {
                            NavigationLink {
                                ProSyncPlaceholderView()
                            } label: {
                                SettingsRow(icon: "icloud", title: "iCloud 同步（Pro）", subtitle: "敬请期待")
                            }
                        }

                        settingsGroup {
                            Button(role: .destructive) {
                                viewModel.showClearAllConfirm = true
                            } label: {
                                SettingsRow(icon: "trash", title: "清空所有数据", tint: .red)
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(spacing: 10) {
                            OnboardingLogoMark()
                                .frame(width: 56, height: 36)
                            Text("PassTalk v1.0.0")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text("Local-first · 数据仅保留在本机")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("确认清空所有数据？", isPresented: $viewModel.showClearAllConfirm) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) { viewModel.clearAllData() }
            }
            .confirmationDialog("选择导入格式", isPresented: $showImportFormatDialog, titleVisibility: .visible) {
                Button("CSV") {
                    selectedImportFormat = .csv
                    showImporter = true
                }
                Button("Bitwarden JSON") {
                    selectedImportFormat = .bitwarden
                    showImporter = true
                }
                Button("1Password JSON") {
                    selectedImportFormat = .onePassword
                    showImporter = true
                }
                Button("PassTalk JSON") {
                    selectedImportFormat = .json
                    showImporter = true
                }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog("选择导出格式", isPresented: $showExportFormatDialog, titleVisibility: .visible) {
                Button("CSV") { export(format: .csv) }
                Button("JSON") { export(format: .json) }
                Button("取消", role: .cancel) {}
            }
            .alert("提示", isPresented: Binding(get: {
                viewModel.toast != nil
            }, set: { newValue in
                if !newValue { viewModel.toast = nil }
            })) {
                Button("知道了", role: .cancel) { viewModel.toast = nil }
            } message: {
                Text(viewModel.toast ?? "")
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.commaSeparatedText, .json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    guard let url = urls.first,
                          let data = try? Data(contentsOf: url) else {
                        viewModel.toast = "导入失败"
                        return
                    }
                    do {
                        let report = try importService.importEntries(from: data, format: selectedImportFormat)
                        viewModel.toast = "导入完成：\(report.importedCount) 条，跳过 \(report.skippedCount) 条"
                    } catch {
                        viewModel.toast = "导入失败"
                    }
                case .failure:
                    viewModel.toast = "导入取消"
                }
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportedDocument,
                contentType: .json,
                defaultFilename: "PassTalk-export"
            ) { _ in }
        }
    }

    private func export(format: ExportFormat) {
        do {
            let data = try exportService.exportEntries(format: format)
            let type: UTType = (format == .csv) ? .commaSeparatedText : .json
            exportedDocument = PassTalkDocument(data: data, contentType: type)
            showExporter = true
        } catch {
            viewModel.toast = "导出失败"
        }
    }

    @ViewBuilder
    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = .primary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(tint)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white)
    }
}

private struct HowToUseView: View {
    let onReplayOnboarding: () -> Void

    var body: some View {
        List {
            Section("使用方式") {
                Text("像聊天一样输入：平台 + 账号 + 密码。")
                Text("当信息缺失时，AI 会自动追问并提示补充。")
                Text("你也可以直接问：例如“查 GitHub 密码”。")
            }
            Section {
                Button("重新查看首次引导") {
                    onReplayOnboarding()
                }
            }
        }
        .navigationTitle("如何使用")
    }
}

private struct AboutPassTalkView: View {
    var body: some View {
        List {
            Section("产品信息") {
                Text("PassTalk v1.0")
                Text("对话式密码管理工具，让记录与查找更自然。")
            }
            Section("设计原则") {
                Text("Local-first：你的数据优先保存在本地。")
                Text("Simple flow：尽量通过自然语言完成操作。")
            }
        }
        .navigationTitle("关于 PassTalk")
    }
}

private struct PrivacySecurityView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var endpoint: String
    @Binding var model: String
    @Binding var systemPrompt: String
    @Binding var apiKey: String
    let onSave: () -> Void

    var body: some View {
        List {
            Section("AI 提供商配置") {
                TextField("Endpoint（例如 https://api.longcat.chat/openai ）", text: $endpoint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                TextField("Model（例如 gpt-4.1-mini）", text: $model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                VStack(alignment: .leading, spacing: 4) {
                    Text("System Prompt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 80)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                }

                SecureField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("保存配置") {
                    onSave()
                }

                Button {
                    viewModel.testConnection()
                } label: {
                    HStack {
                        Text("测试连接")
                        if viewModel.isTestingConnection {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.isTestingConnection)

                if let msg = viewModel.testResultMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(msg.contains("成功") ? .green : .red)
                }
            }
            Section("说明") {
                Text("可填写 OpenAI 或兼容 OpenAI 协议的服务。Endpoint 支持填写 base URL，应用会自动补全到请求地址。")
                    .foregroundStyle(.secondary)
                Text("V1 仅将必要的文本发送到 AI API，密码数据本地存储。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("隐私与安全")
    }
}

private struct OnboardingLogoMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
            HStack(spacing: 6) {
                Circle().fill(Color.gray.opacity(0.65)).frame(width: 6, height: 6)
                Circle().fill(Color.gray.opacity(0.35)).frame(width: 6, height: 6)
                Circle().fill(Color.orange).frame(width: 6, height: 6)
            }
        }
    }
}

struct PassTalkDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }

    let data: Data
    let contentType: UTType

    init(data: Data, contentType: UTType) {
        self.data = data
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
        self.contentType = configuration.contentType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
