//
//  ConfigDetailView.swift
//  配置详情（液态玻璃）：节点 / 策略组 / 规则三个区段
//

import SwiftUI

struct ConfigDetailView: View {
    let config: ProxyConfig
    @EnvironmentObject var store: ConfigStore

    var body: some View {
        ZStack {
            GlassBackground()
            List {
                Section {
                    row("格式", config.format.rawValue)
                    HStack {
                        Text("启用这份配置")
                        Spacer()
                        if store.selectedConfigID == config.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(GlassTheme.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { store.select(config.id) }
                }
                .listRowBackground(rowBg)

                Section("策略组（\(config.groups.count)）") {
                    if config.groups.isEmpty { Text("无").foregroundStyle(.secondary) }
                    ForEach(config.groups) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(group.name).font(.subheadline).bold()
                                Spacer()
                                Text(group.typeDisplayName)
                                    .font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(GlassTheme.purple.opacity(0.25))
                                    .clipShape(Capsule())
                            }
                            Text(group.members.joined(separator: "、"))
                                .font(.caption).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                .listRowBackground(rowBg)

                Section("节点（\(config.nodes.count)）") {
                    if config.nodes.isEmpty {
                        Text("无（可能是纯规则配置）").foregroundStyle(.secondary)
                    }
                    ForEach(config.nodes) { node in
                        HStack {
                            Text(node.typeDisplayName)
                                .font(.caption2).monospaced()
                                .frame(width: 76, alignment: .leading)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(GlassTheme.accent.opacity(0.2))
                                .clipShape(Capsule())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(node.name).font(.subheadline).lineLimit(1)
                                Text("\(node.server):\(node.port)")
                                    .font(.caption2).foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }
                }
                .listRowBackground(rowBg)

                Section("规则（前 100 条）") {
                    ForEach(Array(config.rules.prefix(100))) { rule in
                        HStack(alignment: .top, spacing: 8) {
                            Text(rule.kind)
                                .font(.caption2).monospaced()
                                .frame(width: 104, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.payload.isEmpty ? "—" : rule.payload)
                                    .font(.caption).lineLimit(1)
                                Text("→ \(rule.policyDisplayName)")
                                    .font(.caption2).foregroundStyle(policyColor(rule.policy))
                            }
                        }
                    }
                }
                .listRowBackground(rowBg)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(config.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var rowBg: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.white.opacity(0.08))
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k)
            Spacer()
            Text(v).foregroundStyle(.white.opacity(0.7))
        }
    }

    private func policyColor(_ policy: String) -> Color {
        switch policy.uppercased() {
        case "DIRECT": return GlassTheme.accent
        case "REJECT": return GlassTheme.red
        default: return GlassTheme.green
        }
    }
}
