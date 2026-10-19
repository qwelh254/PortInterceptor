//
//  BlocklistMatcher.swift
//  内置大型拦截列表（anti-AD，约 11 万真实域名）的高效匹配
//  采用「逐级后缀 + Set」匹配：对 host 按标签逐级生成后缀，各做一次 O(1) 查询
//  例如 a.b.example.com 依次检查 a.b.example.com / b.example.com / example.com
//

import Foundation

public final class BlocklistMatcher: Sendable {
    private let suffixes: Set<String>
    public let enabled: Bool
    public let count: Int

    public init(enabled: Bool) {
        self.enabled = enabled
        let set = BlocklistMatcher.load()
        self.suffixes = set
        self.count = set.count
    }

    /// 从 App Bundle 加载内置域名列表
    static func load() -> Set<String> {
        guard let url = Bundle.main.url(forResource: "blocklist", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        var set = Set<String>()
        text.enumerateLines { line, _ in
            let l = line.trimmingCharacters(in: .whitespaces)
            if !l.isEmpty { set.insert(l) }
        }
        return set
    }

    /// 域名是否命中内置拦截列表
    public func contains(_ host: String) -> Bool {
        guard enabled, !suffixes.isEmpty else { return false }
        let labels = host.split(separator: ".")
        for i in labels.indices {
            if suffixes.contains(labels[i...].joined(separator: ".")) {
                return true
            }
        }
        return false
    }
}
