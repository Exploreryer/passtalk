import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let importService: ImportServiceProtocol
    let exportService: ExportServiceProtocol
    let onReplayOnboarding: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.96).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        settingsGroup {
                            Button {
                                dismiss()
                                DispatchQueue.main.async {
                                    onReplayOnboarding()
                                }
                            } label: {
                                SettingsRow(icon: "book.closed", title: "如何使用")
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                PrivacySecurityView(
                                    viewModel: viewModel,
                                    endpoint: $viewModel.endpoint,
                                    model: $viewModel.model,
                                    apiKey: $viewModel.apiKey,
                                    onSave: { viewModel.saveAPISettings() }
                                )
                            } label: {
                                SettingsRow(icon: "shield", title: "隐私与安全")
                            }
                        }

                        settingsGroup {
                            NavigationLink {
                                ImportDataView(importService: importService)
                            } label: {
                                SettingsRow(icon: "square.and.arrow.down", title: "导入数据")
                            }

                            NavigationLink {
                                ExportDataView(exportService: exportService)
                            } label: {
                                SettingsRow(icon: "square.and.arrow.up", title: "导出数据")
                            }
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
            .alert("提示", isPresented: Binding(get: {
                viewModel.toast != nil
            }, set: { newValue in
                if !newValue { viewModel.toast = nil }
            })) {
                Button("知道了", role: .cancel) { viewModel.toast = nil }
            } message: {
                Text(viewModel.toast ?? "")
            }
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

private struct ImportDataView: View {
    let importService: ImportServiceProtocol

    @State private var selectedFormatIndex = 0
    @State private var showImporter = false
    @State private var resultMessage: String?

    private let formatOptions: [(title: String, format: ImportFormat)] = [
        ("CSV", .csv),
        ("Bitwarden JSON", .bitwarden),
        ("1Password JSON", .onePassword),
        ("PassTalk JSON", .json)
    ]

    private var selectedFormat: ImportFormat {
        formatOptions[selectedFormatIndex].format
    }

    var body: some View {
        List {
            Section("导入格式") {
                Picker("格式", selection: $selectedFormatIndex) {
                    ForEach(Array(formatOptions.enumerated()), id: \.offset) { index, option in
                        Text(option.title).tag(index)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section {
                Button("选择文件并导入") {
                    showImporter = true
                }
            }
        }
        .navigationTitle("导入数据")
        .alert("提示", isPresented: Binding(get: {
            resultMessage != nil
        }, set: { newValue in
            if !newValue { resultMessage = nil }
        })) {
            Button("知道了", role: .cancel) { resultMessage = nil }
        } message: {
            Text(resultMessage ?? "")
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
                    resultMessage = "导入失败"
                    return
                }
                do {
                    let report = try importService.importEntries(from: data, format: selectedFormat)
                    resultMessage = "导入完成：\(report.importedCount) 条，跳过 \(report.skippedCount) 条"
                } catch {
                    resultMessage = "导入失败"
                }
            case .failure:
                resultMessage = "导入取消"
            }
        }
    }
}

private struct ExportDataView: View {
    let exportService: ExportServiceProtocol

    @State private var selectedFormatIndex = 0
    @State private var showExporter = false
    @State private var exportedDocument: PassTalkDocument?
    @State private var resultMessage: String?

    private let formatOptions: [(title: String, format: ExportFormat)] = [
        ("CSV", .csv),
        ("JSON", .json)
    ]

    private var selectedFormat: ExportFormat {
        formatOptions[selectedFormatIndex].format
    }

    var body: some View {
        List {
            Section("导出格式") {
                Picker("格式", selection: $selectedFormatIndex) {
                    ForEach(Array(formatOptions.enumerated()), id: \.offset) { index, option in
                        Text(option.title).tag(index)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section {
                Button("导出文件") {
                    export()
                }
            }
        }
        .navigationTitle("导出数据")
        .alert("提示", isPresented: Binding(get: {
            resultMessage != nil
        }, set: { newValue in
            if !newValue { resultMessage = nil }
        })) {
            Button("知道了", role: .cancel) { resultMessage = nil }
        } message: {
            Text(resultMessage ?? "")
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportedDocument,
            contentType: selectedFormat == .csv ? .commaSeparatedText : .json,
            defaultFilename: "PassTalk-export"
        ) { exportResult in
            if case let .failure(error) = exportResult {
                resultMessage = "导出失败：\(error.localizedDescription)"
            }
        }
    }

    private func export() {
        do {
            let data = try exportService.exportEntries(format: selectedFormat)
            let type: UTType = selectedFormat == .csv ? .commaSeparatedText : .json
            exportedDocument = PassTalkDocument(data: data, contentType: type)
            showExporter = true
        } catch {
            resultMessage = "导出失败"
        }
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

private struct PrivacySecurityView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var endpoint: String
    @Binding var model: String
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
                Text("对话助手人设与解析策略由应用内置，不在设置页暴露。")
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
