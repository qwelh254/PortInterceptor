//
//  LocalRuleMatcher.swift
//  App 内本地代理使用的同步规则匹配器（线程安全，规则快照不可变）
//  判定顺序：用户配置规则（含白名单 DIRECT，优先）→ 内置大型拦截列表 → 最终策略
//

import Foundation

public final class LocalRuleMatcher: Sendable {
    private let rules: [Rule]
    private let finalPolicy: String
    private let hasNodes: Bool
    private let blocklist: BlocklistMatcher
    /// 拦截开关：false = 直连模式（不拦截，REJECT 也放行）
    public let blockEnabled: Bool

    public init(config: ProxyConfig,
                blockEnabled: Bool,
                builtinEnabled: Bool) {
        self.rules = config.rules
        self.finalPolicy = config.finalPolicy
        self.hasNodes = !config.nodes.isEmpty
        self.blockEnabled = blockEnabled
        self.blocklist = BlocklistMatcher(enabled: builtinEnabled)
    }

    public enum Decision: Sendable {
        case direct, blocked, proxied
    }

    /// 返回对该域名应执行的最终动作
    public func decision(for host: String) -> Decision {
        let domain = normalize(host)
        var policy: String?
        for rule in rules {
            if matches(rule: rule, domain: domain) {
                policy = rule.policy
                break
            }
        }
        if policy == nil {
            // 用户规则未命中：查内置大型拦截列表（需拦截开关 + 内置列表启用）
            if blockEnabled, blocklist.contains(domain) {
                return .blocked
            }
        }
        return resolve(policy ?? finalPolicy)
    }

    // MARK: - 匹配
    private func matches(rule: Rule, domain: String) -> Bool {
        switch rule.kind {
        case "DOMAIN":
            return domain == rule.payload.lowercased()
        case "DOMAIN-SUFFIX":
            return domain == rule.payload.lowercased()
                || domain.hasSuffix("." + rule.payload.lowercased())
        case "DOMAIN-KEYWORD":
            return domain.contains(rule.payload.lowercased())
        case "DOMAIN-REGEX":
            return domain.range(of: rule.payload,
                                options: [.regularExpression, .caseInsensitive]) != nil
        default:
            // IP-CIDR / GEOIP / RULE-SET 等需要 IP 解析或外部规则集，本地代理按域名判定时跳过
            return false
        }
    }

    private func resolve(_ policy: String) -> Decision {
        let p = policy.uppercased()
        if p == "DIRECT" {
            return .direct
        }
        if p == "REJECT" {
            // 直连模式（拦截开关关闭）时，拦截规则也放行
            return blockEnabled ? .blocked : .direct
        }
        // 命名节点 / 策略组：免费账号无可用加密节点时，统一直连，保证能上网
        return hasNodes ? .proxied : .direct
    }

    private func normalize(_ input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespaces)
        if let comps = URLComponents(string: s), let host = comps.host {
            s = host
        }
        if let colon = s.range(of: ":"), s.contains(".") {
            let after = s[colon.upperBound..<s.endIndex]
            if after.allSatisfy({ $0.isNumber }) {
                s = String(s[s.startIndex..<colon.lowerBound])
            }
        }
        return s.lowercased()
    }
}
