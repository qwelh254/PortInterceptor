//
//  ConnectionView.swift
//  连接页（液态玻璃）：本地代理启停、状态、统计、拦截开关、门户验证、WiFi 五步引导
//

import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var store: ConfigStore
    @EnvironmentObject var proxy: ProxyServerManager
    @Environment(\.openURL) private var openURL

    private let verifyURL = URL(string: "http://captive.apple.com/hotspot-detect.html")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    statusHeader
                    toggleButton
                    statsRow
                    blockSwitch
                    portalCard
                    wifiGuide
                    if case .error(let m) = proxy.state {
                        Label(m, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote).foregroundStyle(GlassTheme.red)
                            .frame(maxWidth: .infinity).padding()
                            .background(GlassTheme.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - 盾牌状态
    private var statusHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(colors: running
                                       ? [GlassTheme.green.opacity(0.35), GlassTheme.green.opacity(0.05)]
                                       : [.white.opacity(0.14), .white.opacity(0.04)],
                                       center: .center, startRadius: 4, endRadius: 130)
                    )
                    .frame(width: 190, height: 190)
                    .overlay(
                        Circle().stroke(running ? GlassTheme.green.opacity(0.6) : .white.opacity(0.25),
                                        lineWidth: 1.5)
                    )
                if running {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 78)).foregroundStyle(GlassTheme.green)
                } else {
                    Image(systemName: "shield")
                        .font(.system(size: 74)).foregroundStyle(.white.opacity(0.7))
                        .overlay(
                            Rectangle().frame(width: 105, height: 5)
                                .rotationEffect(.degrees(-45))
                                .foregroundStyle(.white.opacity(0.7))
                        )
                }
            }
            .padding(.top, 14)

            Text(statusText)
                .font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
            Text(proxy.addressText)
                .font(.system(size: 19, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
            if let config = store.selected {
                Text("当前配置：\(config.name)")
                    .font(.footnote).foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    // MARK: - 启停按钮
    private var toggleButton: some View {
        Button {
            if running { proxy.stop() }
            else if let config = store.selected { proxy.start(with: config) }
        } label: {
            Text(running ? "停止代理" : "启动代理")
                .font(.system(size: 18, weight: .bold))
                .frame(maxWidth: .infinity).padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(running ? GlassTheme.red : GlassTheme.green)
        .disabled(store.configs.isEmpty)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: (running ? GlassTheme.red : GlassTheme.green).opacity(0.35),
                radius: 14, y: 8)
    }

    // MARK: - 统计卡片
    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(value: proxy.total, title: "总请求",
                     icon: "number", color: .white)
            StatCard(value: proxy.blocked, title: "已拦截",
                     icon: "xmark.octagon.fill", color: GlassTheme.red)
            StatCard(value: proxy.direct, title: "直连",
                     icon: "checkmark.circle.fill", color: GlassTheme.green)
        }
    }

    // MARK: - 拦截开关
    private var blockSwitch: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("拦截开关").font(.system(size: 18, weight: .semibold))
                Text(proxy.blockEnabled ? "拦截模式（按规则 REJECT）" : "直连模式（全部放行）")
                    .font(.system(size: 13.5)).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { proxy.blockEnabled },
                set: { proxy.setBlockEnabled($0) }
            ))
            .labelsHidden().tint(GlassTheme.green)
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - 门户验证
    private var portalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("门户验证", systemImage: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(GlassTheme.accent)
            Text("代理运行中，点下面按钮在 Safari 打开验证页，会显示「端口验证成功」；若关闭代理再打开，则直接显示原始网页（如百度）。")
                .font(.system(size: 13.5)).foregroundStyle(.white.opacity(0.65))
            Button {
                openURL(verifyURL)
            } label: {
                Label("打开验证网页", systemImage: "safari")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(GlassTheme.accent)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .disabled(!running)
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - WiFi 五步引导
    private var wifiGuide: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("WiFi 代理设置", systemImage: "wifi")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(GlassTheme.accent)
            GuideStep(1, "设置 → 无线局域网")
            GuideStep(2, "点已连 WiFi 的 ⓘ")
            GuideStep(3, "配置代理 → 手动")
            GuideStep(4, "服务器：127.0.0.1")
            GuideStep(5, "端口：8888 → 存储")
            Button {
                proxy.resetStats()
            } label: {
                Label("清零统计", systemImage: "arrow.counterclockwise")
                    .font(.footnote)
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.6))
            .padding(.top, 4)
        }
        .padding(18)
        .glassCard()
    }

    private var running: Bool { proxy.isRunning }
    private var statusText: String { running ? "运行中" : "未连接" }
}

// MARK: - 统计玻璃卡片
struct StatCard: View {
    let value: Int
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 21)).foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
            Text(title)
                .font(.system(size: 13.5)).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .glassCard()
    }
}

// MARK: - 引导步骤
struct GuideStep: View {
    let index: Int
    let text: String
    init(_ index: Int, _ text: String) { self.index = index; self.text = text }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(GlassTheme.accent.opacity(0.22)).frame(width: 28, height: 28)
                Text("\(index)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(GlassTheme.accent)
            }
            Text(text).font(.system(size: 15)).foregroundStyle(.white.opacity(0.9))
        }
    }
}
