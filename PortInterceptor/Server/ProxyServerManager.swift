//
//  ProxyServerManager.swift
//  本地代理的启停与状态管理（App 内，无需 Network Extension）
//  连接页通过它启动/停止 127.0.0.1:8888，并读取统计、切换拦截开关
//

import Foundation
import SwiftUI

@MainActor
public final class ProxyServerManager: ObservableObject {
    public enum State: Equatable {
        case off, running, error(String)
    }

    @Published public var state: State = .off
    @Published public var total = 0
    @Published public var blocked = 0
    @Published public var direct = 0
    @Published public var proxied = 0
    /// 拦截开关：false = 直连模式（全部放行）
    @Published public var blockEnabled = false

    public static let defaultHost = "127.0.0.1"
    public static let defaultPort: UInt16 = 8888

    private var server: LocalProxyServer?
    private let stats = ProxyStats()
    private var activeConfig: ProxyConfig?
    private var refreshTimer: Timer?

    public init() {}

    public var isRunning: Bool { state == .running }

    public var addressText: String {
        "\(Self.defaultHost):\(Self.defaultPort)"
    }

    // MARK: - 启动
    public func start(with config: ProxyConfig) {
        stopInternal(clearStats: false)
        let matcher = LocalRuleMatcher(config: config, blockEnabled: blockEnabled)
        let server = LocalProxyServer(port: Self.defaultPort,
                                      matcher: matcher,
                                      stats: stats,
                                      configName: config.name,
                                      nodeCount: config.nodes.count,
                                      ruleCount: config.rules.count)
        do {
            try server.start()
            self.server = server
            self.activeConfig = config
            self.state = .running
            startTimer()
        } catch {
            self.state = .error("本地代理启动失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 停止
    public func stop() {
        stopInternal(clearStats: false)
        state = .off
    }

    private func stopInternal(clearStats: Bool) {
        server?.stop()
        server = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
        if clearStats { stats.reset() }
    }

    // MARK: - 切换拦截开关
    public func setBlockEnabled(_ enabled: Bool) {
        blockEnabled = enabled
        guard let config = activeConfig, let server = server else { return }
        let matcher = LocalRuleMatcher(config: config, blockEnabled: enabled)
        server.updateMatcher(matcher)
    }

    // MARK: - 统计清零
    public func resetStats() {
        stats.reset()
        refresh()
    }

    // MARK: - 定时刷新统计
    private func startTimer() {
        refreshTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
        refresh()
    }

    private func refresh() {
        let s = stats.snapshot()
        total = s.total
        blocked = s.blocked
        direct = s.direct
        proxied = s.proxied
    }
}
