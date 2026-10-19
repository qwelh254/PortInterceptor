//
//  ProxyStats.swift
//  代理统计（线程安全）：总请求 / 已拦截 / 直连 / 走代理
//  LocalProxyServer 在后台队列写入，ProxyServerManager 在主线程定时读取快照
//

import Foundation

public final class ProxyStats: @unchecked Sendable {
    private let lock = NSLock()
    private var _total = 0
    private var _blocked = 0
    private var _direct = 0
    private var _proxied = 0

    public struct Snapshot: Sendable, Equatable {
        public let total, blocked, direct, proxied: Int
    }

    public init() {}

    public func record(_ outcome: Outcome) {
        lock.lock()
        _total += 1
        switch outcome {
        case .blocked: _blocked += 1
        case .direct:  _direct += 1
        case .proxied: _proxied += 1
        }
        lock.unlock()
    }

    public func snapshot() -> Snapshot {
        lock.lock()
        let s = Snapshot(total: _total, blocked: _blocked, direct: _direct, proxied: _proxied)
        lock.unlock()
        return s
    }

    public func reset() {
        lock.lock()
        _total = 0; _blocked = 0; _direct = 0; _proxied = 0
        lock.unlock()
    }

    public enum Outcome: Sendable {
        case blocked, direct, proxied
    }
}
