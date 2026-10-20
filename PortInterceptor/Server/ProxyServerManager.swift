//
//  ProxyServerManager.swift
//  本地代理的启停与状态管理（App 内，无需 Network Extension）
//  连接页通过它启动/停止代理，并读取统计、切换拦截开关、设置端口与内置规则
//
//  v4.1：设置与运行状态持久化（重启 App / 划掉后台后自动恢复）
//

import Foundation
import SwiftUI
import UIKit

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
    @Published public var blockEnabled = false {
        didSet { persist() }
    }
    /// 内置大型拦截规则开关（约 11 万域名）
    @Published public var builtinEnabled = true {
        didSet { persist() }
    }
    /// 监听端口
    @Published public var port: UInt16 = 8888 {
        didSet { persist() }
    }

    public static let defaultHost = "127.0.0.1"
    public static let defaultPort: UInt16 = 8888

    private enum UDKey {
        static let port = "proxy.port"
        static let blockEnabled = "proxy.blockEnabled"
        static let builtinEnabled = "proxy.builtinEnabled"
        static let wasRunning = "proxy.wasRunning"
    }

    private var server: LocalProxyServer?
    private let stats = ProxyStats()
    public let requestLog = RequestLog()
    private var activeConfig: ProxyConfig?
    private var refreshTimer: Timer?

    public init() {
        let ud = UserDefaults.standard
        if ud.object(forKey: UDKey.port) != nil {
            let p = ud.integer(forKey: UDKey.port)
            if (1024...65535).contains(p) { port = UInt16(p) }
        }
        if let b = ud.object(forKey: UDKey.blockEnabled) as? Bool { blockEnabled = b }
        if let b = ud.object(forKey: UDKey.builtinEnabled) as? Bool { builtinEnabled = b }
        // 进入后台时不被挂起：延长后台执行时间（配合后台模式）
        NotificationCenter.default.addObserver(
            self, selector: #selector(enteredBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    public var isRunning: Bool { state == .running }

    public var addressText: String {
        "\(Self.defaultHost):\(port)"
    }

    /// 上次是否处于运行状态（用于 App 启动时恢复）
    public var wasRunning: Bool {
        UserDefaults.standard.bool(forKey: UDKey.wasRunning)
    }

    // MARK: - 启动
    public func start(with config: ProxyConfig) {
        stopInternal(clearStats: false)
        let matcher = LocalRuleMatcher(config: config,
                                       blockEnabled: blockEnabled,
                                       builtinEnabled: builtinEnabled)
        let server = LocalProxyServer(port: port,
                                      matcher: matcher,
                                      stats: stats,
                                      log: requestLog,
                                      configName: config.name,
                                      nodeCount: config.nodes.count,
                                      ruleCount: config.rules.count)
        do {
            try server.start()
            self.server = server
            self.activeConfig = config
            self.state = .running
            startTimer()
            UserDefaults.standard.set(true, forKey: UDKey.wasRunning)
            KeepAlive.shared.start()
        } catch {
            self.state = .error("本地代理启动失败：\(error.localizedDescription)")
            UserDefaults.standard.set(false, forKey: UDKey.wasRunning)
        }
    }

    // MARK: - 停止
    public func stop() {
        stopInternal(clearStats: false)
        state = .off
        UserDefaults.standard.set(false, forKey: UDKey.wasRunning)
        KeepAlive.shared.stop()
    }

    /// App 启动后：若上次运行中，自动恢复代理
    public func restoreIfNeeded(with config: ProxyConfig) {
        guard wasRunning, !isRunning else { return }
        start(with: config)
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
        let matcher = LocalRuleMatcher(config: config,
                                       blockEnabled: enabled,
                                       builtinEnabled: builtinEnabled)
        server.updateMatcher(matcher)
    }

    // MARK: - 切换内置规则
    public func setBuiltinEnabled(_ enabled: Bool) {
        builtinEnabled = enabled
        guard let config = activeConfig, let server = server else { return }
        let matcher = LocalRuleMatcher(config: config,
                                       blockEnabled: blockEnabled,
                                       builtinEnabled: enabled)
        server.updateMatcher(matcher)
    }

    // MARK: - 端口修改（保存，下次启动生效）
    public func setPort(_ newPort: UInt16) {
        guard (1024...65535).contains(newPort) else { return }
        port = newPort
    }

    // MARK: - 统计与日志清零
    public func resetStats() {
        stats.reset()
        requestLog.reset()
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

    private func persist() {
        let ud = UserDefaults.standard
        ud.set(Int(port), forKey: UDKey.port)
        ud.set(blockEnabled, forKey: UDKey.blockEnabled)
        ud.set(builtinEnabled, forKey: UDKey.builtinEnabled)
    }

    @objc private func enteredBackground() {
        // 进入后台后请求额外的执行时间，尽量保持代理存活
        KeepAlive.shared.beginBackgroundTask()
    }
}
