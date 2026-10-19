//
//  RuleTestView.swift
//  规则测试页（液态玻璃）：输入域名/网址，查看按当前配置会被直连、拦截还是走代理
//

import SwiftUI

struct RuleTestView: View {
    @EnvironmentObject var store: ConfigStore
    @State private var input = ""
    @State private var result: RuleMatchResult?
    @State private var testedHost = ""

    private let samples = ["www.google.com", "www.apple.com", "api.taobao.com",
                           "www.youtube.com", "baidu.com", "telemetry.microsoft.com"]

    var body: some View {
        NavigationStack {
            Group {
                if store.configs.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            configPicker
                            inputCard
                            if let result { resultCard(result) }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("规则测试")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                    .frame(width: 92, height: 92)
                    .overlay { Circle().strokeBorder(.white.opacity(0.25)) }
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 40)).foregroundStyle(GlassTheme.accent)
            }
            Text("请先导入配置").font(.headline)
            Text("在「配置」页导入后即可测试规则拦截")
                .font(.subheadline).foregroundStyle(.white.opacity(0.65))
        }
    }

    private var configPicker: some View {
        Picker("使用配置", selection: Binding(
            get: { store.selectedConfigID ?? store.configs.first?.id ?? UUID() },
            set: { store.select($0) }
        )) {
            ForEach(store.configs) { cfg in
                Text(cfg.name).tag(cfg.id)
            }
        }
        .pickerStyle(.menu)
        .padding(14)
        .glassCard()
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("输入要测试的域名或网址")
                .font(.subheadline).foregroundStyle(.white.opacity(0.7))
            HStack {
                TextField("例如 www.google.com", text: $input)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .autocapitalization(.none)
                    .onSubmit { runTest() }
                Button("测试") { runTest() }
                    .buttonStyle(.borderedProminent)
                    .tint(GlassTheme.accent)
                    .foregroundStyle(.black)
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(samples, id: .self) { s in
                        Button(s) { input = s; runTest() }
                            .font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(.white.opacity(0.12))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    @ViewBuilder
    private func resultCard(_ r: RuleMatchResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: iconName(r.targetType))
                    .font(.system(size: 34)).foregroundStyle(iconColor(r.targetType))
                VStack(alignment: .leading, spacing: 4) {
                    Text(testedHost).font(.headline)
                    Text(verdictText(r))
                        .font(.subheadline).bold()
                        .foregroundStyle(iconColor(r.targetType))
                }
            }
            Divider().background(.white.opacity(0.15))
            VStack(alignment: .leading, spacing: 6) {
                Label("命中规则：\(r.kind)", systemImage: "list.bullet.rectangle")
                Label("执行动作：\(r.target)", systemImage: "arrow.right.circle")
            }
            .font(.footnote).foregroundStyle(.white.opacity(0.65))
        }
        .padding(16)
        .glassCard()
    }

    private func runTest() {
        guard let config = store.selected else { return }
        testedHost = input.trimmingCharacters(in: .whitespaces)
        Task {
            let engine = RuleEngine(config: config)
            result = await engine.evaluate(host: testedHost)
        }
    }

    private func iconName(_ t: RuleMatchResult.TargetType) -> String {
        switch t {
        case .direct: return "arrow.up.right.circle"
        case .reject: return "hand.raised.circle"
        case .group, .node: return "globe.asia.australia.fill"
        }
    }

    private func iconColor(_ t: RuleMatchResult.TargetType) -> Color {
        switch t {
        case .direct: return GlassTheme.accent
        case .reject: return GlassTheme.red
        case .group, .node: return GlassTheme.green
        }
    }

    private func verdictText(_ r: RuleMatchResult) -> String {
        switch r.targetType {
        case .direct: return "直连放行（DIRECT）"
        case .reject: return "拦截拒绝（REJECT）"
        case .group: return "走代理策略组：\(r.target)"
        case .node:  return "走代理节点：\(r.target)"
        }
    }
}
