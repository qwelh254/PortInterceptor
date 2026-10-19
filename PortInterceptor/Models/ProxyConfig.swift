//
//  ProxyConfig.swift
//  一份完整配置 = 节点 + 策略组 + 规则，支持本地持久化
//

import Foundation

public enum ConfigFormat: String, Codable {
    case clash          = "Clash YAML"
    case surge          = "Surge / Loon"
    case quantumultX    = "Quantumult X"
    case subscription   = "节点订阅"
    case unknown        = "未知格式"
}

public struct ProxyConfig: Identifiable, Codable {
    public var id: UUID = UUID()
    public var name: String
    public var format: ConfigFormat
    public var nodes: [ProxyNode]
    public var groups: [ProxyGroup]
    public var rules: [Rule]
    public var importedAt: Date
    public var sourceURL: String?

    public init(name: String,
                format: ConfigFormat,
                nodes: [ProxyNode],
                groups: [ProxyGroup],
                rules: [Rule],
                sourceURL: String? = nil) {
        self.name = name
        self.format = format
        self.nodes = nodes
        self.groups = groups
        self.rules = rules
        self.importedAt = Date()
        self.sourceURL = sourceURL
    }

    /// 兜底策略：FINAL / MATCH 规则，没有则默认走代理（若有节点）
    public var finalPolicy: String {
        if let finalRule = rules.first(where: { $0.kind == "FINAL" || $0.kind == "MATCH" }) {
            return finalRule.policy
        }
        return nodes.isEmpty ? "DIRECT" : "PROXY"
    }
}
