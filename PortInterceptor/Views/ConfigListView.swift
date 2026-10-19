//
//  ConfigListView.swift
//  配置页（液态玻璃）：导入（文件 / 剪贴板 / 订阅链接）、自动识别、选择、删除
//

import SwiftUI
import UniformTypeIdentifiers

struct ConfigListView: View {
    @EnvironmentObject var store: ConfigStore
    @State private var showImporter = false
    @State private var showClipboardSheet = false
    @State private var showURLSheet = false
    @State private var importError: String?
    @State private var lastImportedFormat: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(store.configs) { config in
                        NavigationLink {
                            ConfigDetailView(config: config)
                        } label: {
                            ConfigCard(config: config,
                                       selected: store.selectedConfigID == config.id)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            store.select(config.id)
                        })
                        .contextMenu {
                            Button(role: .destructive) {
                                if let idx = store.configs.firstIndex(where: { $0.id == config.id }) {
                                    store.remove(at: IndexSet(integer: idx))
                                }
                            } label: {
                                Label("删除配置", systemImage: "trash")
                            }
                        }
                    }
                    if store.configs.isEmpty { emptyHint }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) { headerBar }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [UTType.yaml, UTType.commaSeparatedText, UTType.text, UTType.data, UTType.item],
                          allowsMultipleSelection: false) { result in handleFile(result) }
            .sheet(isPresented: $showClipboardSheet) {
                TextImportSheet { importText($0) }
            }
            .sheet(isPresented: $showURLSheet) {
                URLImportSheet { importRemote($0) }
            }
            .alert("导入提示", isPresented: .constant(importError != nil)) {
                Button("知道了") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
            .overlay(alignment: .top) {
                if let fmt = lastImportedFormat {
                    Text("已识别为 \(fmt)，导入成功")
                        .font(.footnote)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(GlassTheme.green).foregroundColor(.black)
                        .clipShape(Capsule())
                        .padding(.top, 64)
                }
            }
        }
    }

    // MARK: - 顶部大标题 + 玻璃加号
    private var headerBar: some View {
        HStack {
            Text("配置")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Menu {
                Button { showImporter = true } label: {
                    Label("从文件导入", systemImage: "folder")
                }
                Button { showClipboardSheet = true } label: {
                    Label("从剪贴板导入", systemImage: "doc.on.clipboard")
                }
                Button { showURLSheet = true } label: {
                    Label("从订阅链接导入", systemImage: "link")
                }
            } label: {
                GlassCircleIcon(systemImage: "plus", size: 56)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private var emptyHint: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                    .frame(width: 90, height: 90)
                    .overlay { Circle().strokeBorder(.white.opacity(0.25)) }
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 38)).foregroundStyle(GlassTheme.accent)
            }
            Text("还没有配置").font(.headline)
            Text("点右上角 ＋ 导入 Clash / Surge / 订阅配置\nApp 会自动识别格式")
                .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button { showImporter = true } label: {
                Label("导入第一个配置", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .tint(GlassTheme.accent)
            .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func handleFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let config = try ConfigImporter.parseFile(at: url)
                store.add(config); flashSuccess(config)
            } catch { importError = error.localizedDescription }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func importText(_ text: String) {
        do {
            let config = try ConfigImporter.parseText(text)
            store.add(config); flashSuccess(config)
        } catch { importError = error.localizedDescription }
    }

    private func importRemote(_ urlString: String) {
        Task {
            do {
                let config = try await ConfigImporter.parseRemote(urlString: urlString)
                store.add(config); flashSuccess(config)
            } catch { importError = error.localizedDescription }
        }
    }

    private func flashSuccess(_ config: ProxyConfig) {
        lastImportedFormat = config.format.rawValue
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            lastImportedFormat = nil
        }
    }
}

// MARK: - 配置玻璃卡片
struct ConfigCard: View {
    let config: ProxyConfig
    let selected: bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text(config.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 10) {
                    Text(formatShort(config.format))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(GlassTheme.accent)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(.white.opacity(0.12))
                        .clipShape(Capsule())
                    Label("\(config.nodes.count) 节点", systemImage: "globe")
                        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.75))
                    Label("\(config.rules.count) 规则", systemImage: "list.bullet")
                        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.75))
                }
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26)).foregroundStyle(GlassTheme.green)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(20)
        .glassCard()
    }

    private func formatShort(_ f: ConfigFormat) -> String {
        switch f {
        case .clash:        return "Clash"
        case .surge:        return "Surge / Loon"
        case .quantumultX:  return "QuanX"
        case .subscription: return "订阅"
        case .unknown:      return "未知"
        }
    }
}

// MARK: - 文本导入
struct TextImportSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var text = ""
    let onImport: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()
                VStack(alignment: .leading, spacing: 12) {
                    Text("把配置内容（或整段 Base64 订阅）粘贴到下面，App 会自动识别格式：")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    TextEditor(text: $text)
                        .font(.system(.footnote, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.2)) }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("从剪贴板导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") { onImport(text); dismiss() }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - URL 导入
struct URLImportSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var url = ""
    let onImport: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()
                VStack(alignment: .leading, spacing: 12) {
                    Text("输入机场订阅链接（http(s):// 开头）：")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    TextField("https://example.com/sub?token=...", text: $url)
                        .padding(12)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("订阅链接")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("下载并导入") { onImport(url); dismiss() }
                        .disabled(!url.contains("://"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
