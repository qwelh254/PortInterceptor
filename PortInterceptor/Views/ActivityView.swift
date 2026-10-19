//
//  ActivityView.swift
//  活动页（液态玻璃）：实时请求日志，支持全部 / 已拦截 / 直连筛选、搜索、清空
//

import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var proxy: ProxyServerManager
    @State private var filter: RequestLog.Filter = .all
    @State private var search = ""
    @State private var tick = false

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()
                VStack(spacing: 14) {
                    filterBar
                    if filtered.isEmpty {
                        emptyHint
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(filtered) { entry in
                                    LogRow(entry: entry)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.bottom, 90)
                        }
                    }
                }
                .safeAreaInset(edge: .top) { topBar }
            }
        }
        .onReceive(timer) { _ in tick.toggle() }
    }

    // MARK: - 顶栏
    private var topBar: some View {
        HStack {
            Text("活动").font(.system(size: 36, weight: .bold)).foregroundStyle(.white)
            Spacer()
            Button {
                proxy.requestLog.reset()
            } label: {
                GlassCircleIcon(systemImage: "trash", size: 48)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    // MARK: - 筛选 + 搜索
    private var filterBar: some View {
        VStack(spacing: 10) {
            Picker("筛选", selection: $filter) {
                Text("全部").tag(RequestLog.Filter.all)
                Text("已拦截").tag(RequestLog.Filter.blocked)
                Text("直连").tag(RequestLog.Filter.direct)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 4)

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.6))
                TextField("搜索域名", text: $search)
                    .foregroundStyle(.white)
                    .autocapitalization(.none)
            }
            .padding(10)
            .background(.white.opacity(0.1))
            .clipShape(Capsule())
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 18)
    }

    private var filtered: [RequestLog.Entry] {
        let list = proxy.requestLog.snapshot(filter)
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return list }
        return list.filter { $0.host.lowercased().contains(q) }
    }

    private var emptyHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 44)).foregroundStyle(GlassTheme.accent)
            Text(proxy.isRunning ? "暂时没有符合条件的请求" : "代理未启动")
                .font(.headline)
            Text(proxy.isRunning ? "稍等片刻，新请求会实时显示" : "请先到「连接」页启动代理")
                .font(.subheadline).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }
}

// MARK: - 单条日志
struct LogRow: View {
    let entry: RequestLog.Entry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.host)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(entry.time, style: .time)
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Text(entry.outcomeText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(color.opacity(0.16))
                .clipShape(Capsule())
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
    }

    private var color: Color {
        switch entry.outcome {
        case .blocked: return GlassTheme.red
        case .direct:  return GlassTheme.green
        case .proxied: return GlassTheme.accent
        }
    }

    private var icon: String {
        switch entry.outcome {
        case .blocked: return "hand.raised.fill"
        case .direct:  return "arrow.right"
        case .proxied: return "globe"
        }
    }
}
