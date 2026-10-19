//
//  SubscriptionParser.swift
//  解析节点订阅：裸链接列表，或 Base64 包裹的链接列表
//

import Foundation

public enum SubscriptionParser {

    public static func parse(_ raw: String, name: String? = nil) -> ProxyConfig {
        // 若是 Base64 包裹，先解包
        var text = raw
        if let decoded = ConfigFormatDetector.base64DecodeIfPossible(raw) {
            text = decoded
        }

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let nodes = lines.compactMap { NodeURIParser.parse($0) }

        // 订阅本身一般不带规则，自动建立一个「代理」策略组包含全部节点，
        // 兜底策略 FINAL -> 该组
        var groups: [ProxyGroup] = []
        var rules: [Rule] = []
        if !nodes.isEmpty {
            groups = [ProxyGroup(name: "🚀 节点选择",
                                 type: "select",
                                 members: nodes.map { $0.name } + ["DIRECT"])]
            rules = [Rule(kind: "FINAL", payload: "", policy: "🚀 节点选择", raw: "FINAL,🚀 节点选择")]
        }

        return ProxyConfig(name: name ?? "订阅配置 \(Date().formatted(.dateTime.month().day().hour().minute()))",
                           format: .subscription,
                           nodes: nodes,
                           groups: groups,
                           rules: rules)
    }
}
