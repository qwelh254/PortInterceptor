//
//  SettingsView.swift
//  设置页（液态玻璃）：端口、内置规则、拦截开关、一键内置配置、规则测试、数据重置、关于
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: ConfigStore
    @EnvironmentObject var proxy: ProxyServerManager
    @State private var portText = ""
    @State private var showSaved = false

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        serverCard
                        blocklistCard
                        builtinConfigCard
                        toolsCard
                        dataCard
                        aboutCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 90)
                }
                .safeAreaInset(edge: .top) {
                    Text("设置")
                        .font(.system(size: 36, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 8)
                }
            }
        }
        .onAppear { portText = String(proxy.port) }
        .overlay(alignment: .top) {
            if showSaved {
                Text("已保存")
                    .font(.footnote).padding(.horizontal, 16).padding(.vertical, 10)
                    .background(GlassTheme.green).foregroundColor(.black)
                    .clipShape(Capsule()).padding(.top, 64)
            }
        }
    }

    // MARK: - 服务器
    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("代理服务器", systemImage: "network")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            HStack {
                Text("监听端口").font(.system(size: 14)).foregroundStyle(.white.opacity(0.8))
                Spacer()
                TextField("端口", text: $portText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(GlassTheme.accent)
                    .frame(width: 100)
                    .padding(8).background(.white.opacity(0.1)).clipShape(Capsule())
            }
            Button {
                if let p = UInt16(portText), (1024...65535).contains(p) {
                    proxy.port = p
                    showSaved = true
                    hideHint()
                }
            } label: {
                Text("保存端口（重启代理生效）")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent).tint(GlassTheme.accent)
            .foregroundStyle(.black)
        }
        .padding(20).glassCard()
    }

    // MARK: - 内置规则
    private var blocklistCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("内置拦截规则", systemImage: "shield.lefthalf.filled")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            Toggle(isOn: Binding(get: { proxy.builtinEnabled },
                                 set: { proxy.setBuiltinEnabled($0) })) {
                Text("启用内置大型拦截列表")
                    .font(.system(size: 14)).foregroundStyle(.white)
            }
            .tint(GlassTheme.accent)
            Text("已内置 anti-AD 社区约 11 万个真实广告/追踪域名，无需联网即可拦截；用户配置中的直连（白名单）始终优先。")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
        }
        .padding(20).glassCard()
    }

    // MARK: - 一键内置配置
    private var builtinConfigCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("开箱即用", systemImage: "sparkles")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            Text("还没有配置？可一键生成「内置拦截配置」，导入后到连接页启动即可。")
                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
            Button {
                let cfg = ProxyConfig(name: "内置拦截配置",
                                      format: .surge,
                                      nodes: [], groups: [],
                                      rules: BuiltinRules.rules())
                store.add(cfg)
                showSaved = true
                hideHint()
            } label: {
                Text("一键生成内置配置")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent).tint(GlassTheme.purple)
            .foregroundStyle(.white)
        }
        .padding(20).glassCard()
    }

    // MARK: - 工具
    private var toolsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("工具", systemImage: "wrench.and.screwdriver")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            NavigationLink {
                RuleTestView()
            } label: {
                toolRow("规则测试", "chevron.left.forwardslash.chevron.right")
            }
        }
        .padding(20).glassCard()
    }

    private func toolRow(_ t: String, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(GlassTheme.accent).frame(width: 24)
            Text(t).font(.system(size: 14)).foregroundStyle(.white)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.vertical, 8)
    }

    // MARK: - 数据
    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("数据", systemImage: "tray.full")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            Button(role: .destructive) {
                proxy.resetStats()
                showSaved = true
                hideHint()
            } label: {
                Label("清空统计与日志", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
        .padding(20).glassCard()
    }

    // MARK: - 关于
    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("关于", systemImage: "info.circle")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            Text("端口拦截器 v4.0 · 液态玻璃版")
                .font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
            Text("工作方式：WiFi 手动代理 + 本地规则引擎，无需付费账号即可拦截广告/追踪。全局 VPN 与无视代理 App 的拦截需付费开发者账号的 Network Extension。")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
        }
        .padding(20).glassCard()
    }

    private func hideHint() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { showSaved = false }
    }
}
