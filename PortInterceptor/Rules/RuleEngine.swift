//
//  RuleEngine.swift
//  规则拦截引擎：按顺序匹配规则，决定一个域名/地址应该直连、拦截还是走代理
//
//  支持的规则类型：
//   DOMAIN           精确匹配
//   DOMAIN-SUFFIX    域名后缀匹配
//   DOMAIN-KEYWORD   关键字匹配
//   DOMAIN-REGEX     正则匹配
//   IP-CIDR / IP-CIDR6  IP 段匹配
//   GEOSITE / GEOIP  需要离线规则数据库（工程预留，默认跳过）
//   RULE-SET         需要下载外部规则集（工程预留，默认跳过）
//   FINAL / MATCH    兜底
//

import Foundation

public struct RuleMatchResult: Sendable {
    public let rule: Rule?              // nil 表示命中兜底
    public let kind: String
    public let target: String           // 最终策略：DIRECT / REJECT / 节点或策略组名
    public let targetType: TargetType

    public enum TargetType {
        case direct, reject, group, node
    }
}

public actor RuleEngine {
    private let config: ProxyConfig

    public init(config: ProxyConfig) {
        self.config = config
    }

    /// 对一个域名（或完整 URL）做拦截判定
    public func evaluate(host: String) -> RuleMatchResult {
        let domain = normalize(host)
        for rule in config.rules {
            if matches(rule: rule, domain: domain) {
                return makeResult(rule: rule, target: rule.policy)
            }
        }
        // 兜底
        return makeResult(rule: config.rules.first(where: { $0.kind == "FINAL" || $0.kind == "MATCH" }),
                          target: config.finalPolicy)
    }

    // MARK: - 匹配逻辑
    func matches(rule: Rule, domain: String) -> Bool {
        switch rule.kind {
        case "DOMAIN":
            return domain.caseInsensitiveCompare(rule.payload) == .orderedSame
        case "DOMAIN-SUFFIX":
            return domain == rule.payload
                || domain.hasSuffix("." + rule.payload)
        case "DOMAIN-KEYWORD":
            return domain.lowercased().contains(rule.payload.lowercased())
        case "DOMAIN-REGEX":
            return domain.range(of: rule.payload, options: [.regularExpression, .caseInsensitive]) != nil
        case "IP-CIDR", "IP-CIDR6", "IP-ASN", "GEOIP", "GEOSITE", "RULE-SET", "SRC-IP",
             "DST-PORT", "SRC-PORT", "PROCESS-NAME", "AND", "OR", "NOT":
            // 这些规则需要 IP 解析 / 外部规则集 / 进程信息，纯域名测试时跳过
            return false
        default:
            return false
        }
    }

    func normalize(_ input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespaces)
        if let comps = URLComponents(string: s), let host = comps.host {
            s = host
        }
        // 去掉端口
        if let colon = s.range(of: ":") , s.contains(".") {
            // IPv4 带端口的情况，简单处理：含点且冒号后是数字则去掉端口
            let after = s[colon.upperBound...]
            if after.allSatisfy({ $0.isNumber }) {
                s = String(s[s.startIndex..<colon.lowerBound])
            }
        }
        return s.lowercased()
    }

    func makeResult(rule: Rule?, target: String) -> RuleMatchResult {
        let type: RuleMatchResult.TargetType
        switch target.uppercased() {
        case "DIRECT": type = .direct
        case "REJECT": type = .reject
        default:
            type = config.groups.contains { $0.name == target } ? .group : .node
        }
        return RuleMatchResult(rule: rule,
                               kind: rule?.kind ?? "FINAL",
                               target: target,
                               targetType: type)
    }
}
