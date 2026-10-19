//
//  ClashConfigParser.swift
//  解析 Clash / Clash.Meta / Mihomo 格式的 YAML 配置
//

import Foundation
import Yams

public enum ClashConfigParser {

    public struct ParseError: LocalizedError {
        public let message: String
        public var errorDescription: String? { message }
    }

    public static func parse(_ raw: String, name: String? = nil) throws -> ProxyConfig {
        let object = try Yams.load(yaml: raw)
        guard let yaml = object as? [String: Any] else {
            throw ParseError(message: "Clash 配置解析失败：YAML 顶层不是字典结构")
        }

        let nodes = (yaml["proxies"] as? [[String: Any]])?.map { node(from: $0) } ?? []
        let groups = (yaml["proxy-groups"] as? [[String: Any]])?.map { group(from: $0) } ?? []
        let rules = (yaml["rules"] as? [String])?.compactMap { rule(from: $0) } ?? []

        guard !nodes.isEmpty || !rules.isEmpty else {
            throw ParseError(message: "Clash 配置中没有找到 proxies 或 rules 内容")
        }

        let fileName = name ?? (yaml["mixed-port"] != nil ? "Clash 配置" : "Clash 配置")
        return ProxyConfig(name: fileName,
                           format: .clash,
                           nodes: nodes,
                           groups: groups,
                           rules: rules)
    }

    // MARK: - 节点
    static func node(from d: [String: Any]) -> ProxyNode {
        let type = str(d["type"]) ?? "ss"
        let server = str(d["server"]) ?? ""
        let port = int(d["port"]) ?? 0
        var node = ProxyNode(name: str(d["name"]) ?? server, type: type, server: server, port: port)

        node.password = str(d["password"]) ?? str(d["auth-str"])
        node.cipher = str(d["cipher"])
        node.uuid = str(d["uuid"])
        node.alterId = int(d["alterId"]) ?? int(d["alter-id"])
        node.udp = bool(d["udp"])
        node.network = str(d["network"])
        node.tls = bool(d["tls"])
        node.sni = str(d["sni"]) ?? str(d["servername"])
        node.flow = str(d["flow"])
        node.fingerprint = str(d["client-fingerprint"]) ?? str(d["fp"])
        node.allowInsecure = bool(d["skip-cert-verify"])

        if let ws = d["ws-opts"] as? [String: Any] {
            node.network = "ws"
            node.wsPath = str(ws["path"])
            if let headers = ws["headers"] as? [String: Any] {
                node.wsHost = str(headers["Host"])
            }
        }
        if let grpc = d["grpc-opts"] as? [String: Any] {
            node.network = "grpc"
            node.grpcServiceName = str(grpc["grpc-service-name"])
        }
        if let reality = d["reality-opts"] as? [String: Any] {
            node.tls = true
            node.sni = str(reality["server-name"]) ?? node.sni
        }
        return node
    }

    // MARK: - 策略组
    static func group(from d: [String: Any]) -> ProxyGroup {
        let name = str(d["name"]) ?? "未命名"
        let type = str(d["type"]) ?? "select"
        let members = (d["proxies"] as? [Any])?.compactMap { str($0) } ?? []
        var group = ProxyGroup(name: name, type: type, members: members)
        group.testURL = str(d["url"])
        group.interval = int(d["interval"])
        return group
    }

    // MARK: - 规则
    static func rule(from line: String) -> Rule? {
        let parts = line.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2 else { return nil }
        // 无 policy 的如 MATCH,FINAL?  Clash 规则至少 2 段；MATCH 必须有动作
        let kind = parts[0].uppercased()
        switch kind {
        case "MATCH", "FINAL":
            let policy = parts.count >= 2 ? parts[1] : "DIRECT"
            return Rule(kind: "FINAL", payload: "", policy: policy, raw: line)
        default:
            guard parts.count >= 3 else { return nil }
            let noResolve = parts.contains("no-resolve")
            return Rule(kind: kind, payload: parts[1], policy: parts[2], raw: line, noResolve: noResolve)
        }
    }

    // MARK: - YAML 值类型兜底
    static func str(_ any: Any?) -> String? {
        if let s = any as? String { return s }
        if let n = any as? NSNumber { return n.stringValue }
        if let b = any as? Bool { return b ? "true" : "false" }
        return nil
    }

    static func int(_ any: Any?) -> Int? {
        if let n = any as? Int { return n }
        if let n = any as? NSNumber { return n.intValue }
        if let s = any as? String { return Int(s) }
        return nil
    }

    static func bool(_ any: Any?) -> Bool? {
        if let b = any as? Bool { return b }
        if let s = any as? String { return s == "true" }
        return nil
    }
}
