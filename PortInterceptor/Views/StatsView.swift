//
//  StatsView.swift
//  统计页（液态玻璃）：拦截率圆环、分类条形、被拦截域名 Top 榜
//

import SwiftUI

struct StatsView: View {
    @EnvironmentObject var proxy: ProxyServerManager
    @State private var tick = false
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        ringCard
                        barsCard
                        topBlockedCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 90)
                }
                .safeAreaInset(edge: .top) {
                    Text("统计")
                        .font(.system(size: 36, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 8)
                }
            }
        }
        .onReceive(timer) { _ in tick.toggle() }
    }

    // MARK: - 拦截率圆环
    private var ringCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: blockRate)
                    .stroke(AngularGradient(colors: [GlassTheme.red, GlassTheme.purple, GlassTheme.accent],
                                           center: .center),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(Int(blockRate * 100))%")
                        .font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                    Text("拦截率").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: 130, height: 130)

            VStack(alignment: .leading, spacing: 10) {
                statLine("总请求", proxy.total, .white)
                statLine("已拦截", proxy.blocked, GlassTheme.red)
                statLine("直连", proxy.direct, GlassTheme.green)
                statLine("代理", proxy.proxied, GlassTheme.accent)
            }
            Spacer()
        }
        .padding(20)
        .glassCard()
    }

    private func statLine(_ t: String, _ v: Int, _ c: Color) -> some View {
        HStack {
            Circle().fill(c).frame(width: 8, height: 8)
            Text(t).font(.system(size: 14)).foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text("\(v)").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
        }
    }

    // MARK: - 分类条形
    private var barsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("请求分布").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            bar("直连", proxy.direct, GlassTheme.green)
            bar("已拦截", proxy.blocked, GlassTheme.red)
            bar("代理", proxy.proxied, GlassTheme.accent)
        }
        .padding(20)
        .glassCard()
    }

    private func bar(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label).font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(value)").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(.white.opacity(0.1))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(color)
                            .frame(width: max(4, geo.size.width * share(value)))
                    }
            }
            .frame(height: 10)
        }
    }

    // MARK: - 拦截域名 Top
    private var topBlockedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("被拦截域名 Top").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            let top = proxy.requestLog.topBlocked(limit: 8)
            if top.isEmpty {
                Text("开启拦截并产生请求后，这里会显示被拦截最多的域名")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
            } else {
                ForEach(top.indices, id: \.self) { i in
                    let item = top[i]
                    HStack {
                        Text("\(i + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 22, height: 22)
                            .background(GlassTheme.accent).clipShape(Circle())
                        Text(item.host).font(.system(size: 13)).foregroundStyle(.white).lineLimit(1)
                        Spacer()
                        Text("\(item.count) 次").font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(GlassTheme.red)
                    }
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - 计算
    private var blockRate: CGFloat {
        guard proxy.total > 0 else { return 0 }
        return CGFloat(proxy.blocked) / CGFloat(proxy.total)
    }

    private func share(_ v: Int) -> CGFloat {
        guard proxy.total > 0 else { return 0 }
        return CGFloat(v) / CGFloat(proxy.total)
    }
}
