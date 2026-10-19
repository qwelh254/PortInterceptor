//
//  SharedRuleMatcher.swift
//  扩展内专用的轻量规则匹配器（不依赖主 App 任何文件，可独立编译）
//  数据来自主 App 传入的配置 JSON（字段为 ProxyConfig 的子集，多余字段自动忽略）
//

import Foundation

struct SharedRule: Decodable {
    let kind: String
    let payload: String
    let policy: String
}

struct SharedConfig: Decodable {
    let rules: [SharedRule]?
}

enum SharedAction {
    case direct
    case reject
    case proxy(String)   // 节点名 / 策略组名
}

final class SharedRuleMatcher {
    private let rules: [SharedRule]
    private let finalPolicy: String

    init(configData: Data?) {
        if let data = configData,
           let cfg = try? JSONDecoder().decode(SharedConfig.self, from: data) {
            self.rules = cfg.rules ?? []
        } else {
            self.rules = []
        }
        self.finalPolicy = rules.first { $0.kind == "FINAL" || $0.kind == "MATCH" }?.policy ?? "DIRECT"
    }

    func action(for host: String) -> SharedAction {
        let domain = host.lowercased()
        for rule in rules {
            switch rule.kind {
            case "DOMAIN":
                if domain == rule.payload.lowercased() { return resolve(rule.policy) }
            case "DOMAIN-SUFFIX":
                if domain == rule.payload.lowercased()
                    || domain.hasSuffix("." + rule.payload.lowercased()) {
                    return resolve(rule.policy)
                }
            case "DOMAIN-KEYWORD":
                if domain.contains(rule.payload.lowercased()) { return resolve(rule.policy) }
            default:
                // IP-CIDR / GEOIP / RULE-SET 等：付费版可在此接入 IP 解析与规则集
                break
            }
        }
        return resolve(finalPolicy)
    }

    private func resolve(_ policy: String) -> SharedAction {
        switch policy.uppercased() {
        case "DIRECT": return .direct
        case "REJECT": return .reject
        default:       return .proxy(policy)
        }
    }
}
