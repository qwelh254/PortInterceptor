//
//  RequestLog.swift
//  实时请求日志（线程安全环形缓冲）
//  本地代理在后台队列写入每个请求（时间、域名、协议、决策），活动页在主线程读取
//

import Foundation

public final class RequestLog: @unchecked Sendable {
    public struct Entry: Identifiable, Sendable, Equatable {
        public let id: UUID
        public let time: Date
        public let host: String
        public let scheme: String
        public let outcome: ProxyStats.Outcome

        public var outcomeText: String {
            switch outcome {
            case .blocked: return "已拦截"
            case .direct:  return "直连"
            case .proxied: return "代理"
            }
        }
    }

    private let lock = NSLock()
    private var entries: [Entry] = []
    private let maxCount: Int

    public init(maxCount: Int = 1500) {
        self.maxCount = maxCount
    }

    public func add(host: String, scheme: String, outcome: ProxyStats.Outcome) {
        let entry = Entry(id: UUID(), time: Date(), host: host,
                          scheme: scheme, outcome: outcome)
        lock.lock()
        entries.insert(entry, at: 0)
        if entries.count > maxCount {
            entries.removeLast(entries.count - maxCount)
        }
        lock.unlock()
    }

    /// 读取日志快照，可按结果过滤
    public func snapshot(_ filter: Filter = .all) -> [Entry] {
        lock.lock()
        let copy = entries
        lock.unlock()
        switch filter {
        case .all:     return copy
        case .blocked: return copy.filter { $0.outcome == .blocked }
        case .direct:  return copy.filter { $0.outcome == .direct }
        }
    }

    /// 被拦截域名出现次数排行
    public func topBlocked(limit: Int = 8) -> [(host: String, count: Int)] {
        lock.lock()
        let blocked = entries.filter { $0.outcome == .blocked }
        lock.unlock()
        var counts: [String: Int] = [:]
        for e in blocked { counts[e.host, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }.prefix(limit)
            .map { ($0.key, $0.value) }
    }

    public func reset() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }

    public enum Filter {
        case all, blocked, direct
    }
}
