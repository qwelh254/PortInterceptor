//
//  Rule.swift
//  分流规则模型：DOMAIN / DOMAIN-SUFFIX / DOMAIN-KEYWORD / IP-CIDR / GEOSITE / GEOIP / FINAL ...
//

import Foundation

public struct Rule: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var kind: String            // 规则类型，大写
    public var payload: String         // 规则内容，如 example.com / 192.168.0.0/16
    public var policy: String          // 动作：DIRECT / REJECT / 节点名 / 策略组名
    public var raw: String             // 原始行
    public var noResolve: Bool = false

    public init(kind: String, payload: String, policy: String, raw: String, noResolve: Bool = false) {
        self.kind = kind.uppercased()
        self.payload = payload
        self.policy = policy
        self.raw = raw
        self.noResolve = noResolve
    }
}

public extension Rule {
    /// 策略的中文展示
    var policyDisplayName: String {
        switch policy.uppercased() {
        case "DIRECT": return "直连"
        case "REJECT": return "拦截"
        case "PROXY":  return "代理"
        default:       return policy
        }
    }
}
