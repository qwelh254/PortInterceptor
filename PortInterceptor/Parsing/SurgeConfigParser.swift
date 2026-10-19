//
//  SurgeConfigParser.swift
//  解析 Surge / Loon 风格的 .conf，同时兼容 Quantumult X 的节点行
//  段：[General] [Proxy] [Proxy Group] [Rule]
//

import Foundation

public enum SurgeConfigParser {

    public struct ParseError: LocalizedError {
        public let message: String
        public var errorDescription: String? { message }
    }

    public static func parse(_ raw: String,
                             format: ConfigFormat = .surge,
                             name: String? = nil) throws -> ProxyConfig {
        let lines = raw.components(separatedBy: .newlines)
        var section = ""
        var nodes: [ProxyNode] = []
        var groups: [ProxyGroup] = []
        var rules: [Rule] = []

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") || line.hasPrefix("//") {
                continue
            }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = line.lowercased()
                continue
            }
            switch section {
            case "[proxy]", "[server_local]":
                if let node = parseProxyLine(line, quantumult: section == "[server_local]") {
                    nodes.append(node)
                }
            case "[proxy group]":
                if let group = parseGroupLine(line) {
                    groups.append(group)
                }
            case "[rule]", "[filter_local]":
                if let rule = parseRuleLine(line, quantumult: section == "[filter_local]") {
                    rules.append(rule)
                }
            case "[server_remote]", "[filter_remote]", "[rewrite_remote]", "[rewrite_local]":
                // 远程订阅地址 / 重写规则，需要二次下载，这里忽略
                continue
            default:
                continue
            }
        }

        // Quantumult X 的节点策略名通常是节点 tag，规则里直接引用
        if nodes.isEmpty && rules.isEmpty {
            throw ParseError(message: "配置中没有找到可用的节点或规则（远程订阅地址暂不支持自动下载）")
        }

        return ProxyConfig(name: name ?? (format == .quantumultX ? "Quantumult X 配置" : "Surge 配置"),
                           format: format,
                           nodes: nodes,
                           groups: groups,
                           rules: rules)
    }

    // MARK: - 节点行
    // Surge: 名称 = ss, server, port, method, password
    // Surge: 名称 = vmess, server, port, username=UUID, tls=true, ws=true, ws-path=/path
    // QX:    shadowsocks=server:port method password tag=名称
    static func parseProxyLine(_ line: String, quantumult: Bool) -> ProxyNode? {
        if quantumult {
            return parseQuantumultNode(line)
        }

        guard let eq = line.range(of: "=") else { return nil }
        let nodeName = line[line.startIndex..<eq.lowerBound].trimmingCharacters(in: .whitespaces)
        let body = line[eq.upperBound...].trimmingCharacters(in: .whitespaces)
        let parts = body.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let type = parts.first?.lowercased(), parts.count >= 2 else { return nil }

        func get(_ index: Int) -> String? {
            parts.indices.contains(index) ? parts[index] : nil
        }
        // 支持 key=value 形式取值
        func value(_ key: String) -> String? {
            for p in parts.dropFirst() {
                let kv = p.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if kv.count == 2 && kv[0].lowercased() == key { return kv[1] }
            }
            return nil
        }

        let server = get(1) ?? ""
        let port = Int(get(2) ?? "") ?? 0
        var node = ProxyNode(name: nodeName, type: normalized(type), server: server, port: port)

        switch type {
        case "ss":
            node.cipher = get(3)
            node.password = get(4)
            node.udp = value("udp") == "true"
        case "vmess":
            node.uuid = get(3) ?? value("username")
            node.cipher = value("encrypt") ?? "auto"
            node.alterId = value("alter-id").flatMap(Int.init)
            node.tls = value("tls") == "true"
            node.network = value("ws") == "true" ? "ws" : "tcp"
            node.wsPath = value("ws-path")
            if let headers = value("ws-headers") {
                // 形如 Host:example.com
                let h = headers.replacingOccurrences(of: "Host:", with: "")
                    .replacingOccurrences(of: "host:", with: "")
                node.wsHost = h
            }
        case "trojan":
            node.password = get(3)
            node.tls = true
            node.sni = value("sni") ?? value("server-name")
            node.network = value("ws") == "true" ? "ws" : "tcp"
            node.wsPath = value("ws-path")
        case "http", "https":
            node.username = get(3)
            node.password = get(4)
            node.tls = (type == "https")
        case "socks5", "socks5-tls", "socks":
            node.username = get(3)
            node.password = get(4)
            node.tls = type.hasSuffix("-tls")
        default:
            node.username = get(3)
            node.password = get(4)
        }
        return node
    }

    // Quantumult X 节点行：
    // shadowsocks=server:port method password tag=名称
    // vmess=server:port method=none uuid=xxx tls=1 ws=1 ws-path=/path tag=名称
    // trojan=server:port password tls=1 over-tls=1 sni=xxx tag=名称
    static func parseQuantumultNode(_ line: String) -> ProxyNode? {
        guard let eq = line.range(of: "=") else { return nil }
        let typeRaw = line[line.startIndex..<eq.lowerBound].trimmingCharacters(in: .whitespaces).lowercased()
        let body = line[eq.upperBound...].trimmingCharacters(in: .whitespaces)
        let tokens = body.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }

        func kv(_ key: String) -> String? {
            for t in tokens {
                let pair = t.split(separator: "=", maxSplits: 1).map(String.init)
                if pair.count == 2 && pair[0].lowercased() == key { return pair[1] }
            }
            return nil
        }
        let name = kv("tag")?.removingPercentEncoding ?? tokens[0]

        switch typeRaw {
        case "shadowsocks":
            let hp = tokens[0].split(separator: ":").map(String.init)
            guard hp.count == 2, let port = Int(hp[1]) else { return nil }
            var node = ProxyNode(name: name, type: "ss", server: hp[0], port: port)
            node.cipher = tokens.indices.contains(1) ? tokens[1] : nil
            node.password = tokens.indices.contains(2) ? tokens[2] : nil
            return node
        case "vmess":
            let hp = tokens[0].split(separator: ":").map(String.init)
            guard hp.count == 2, let port = Int(hp[1]) else { return nil }
            var node = ProxyNode(name: name, type: "vmess", server: hp[0], port: port)
            node.cipher = tokens.indices.contains(1) ? tokens[1] : "auto"
            node.uuid = kv("uuid")
            node.tls = kv("tls") == "1"
            node.network = kv("ws") == "1" ? "ws" : "tcp"
            node.wsPath = kv("ws-path")
            node.sni = kv("sni") ?? kv("peer")
            return node
        case "trojan":
            let hp = tokens[0].split(separator: ":").map(String.init)
            guard hp.count == 2, let port = Int(hp[1]) else { return nil }
            var node = ProxyNode(name: name, type: "trojan", server: hp[0], port: port)
            node.password = tokens.indices.contains(1) ? tokens[1] : nil
            node.tls = true
            node.sni = kv("sni") ?? kv("peer")
            return node
        case "http", "https":
            let hp = tokens[0].split(separator: ":").map(String.init)
            guard hp.count == 2, let port = Int(hp[1]) else { return nil }
            var node = ProxyNode(name: name, type: "http", server: hp[0], port: port)
            node.username = tokens.indices.contains(1) ? tokens[1] : nil
            node.password = tokens.indices.contains(2) ? tokens[2] : nil
            node.tls = kv("tls") == "1"
            return node
        case "socks5":
            let hp = tokens[0].split(separator: ":").map(String.init)
            guard hp.count == 2, let port = Int(hp[1]) else { return nil }
            var node = ProxyNode(name: name, type: "socks5", server: hp[0], port: port)
            node.username = tokens.indices.contains(1) ? tokens[1] : nil
            node.password = tokens.indices.contains(2) ? tokens[2] : nil
            return node
        default:
            return nil
        }
    }

    // MARK: - 策略组行
    // 名称 = select, 节点A, 节点B, DIRECT
    static func parseGroupLine(_ line: String) -> ProxyGroup? {
        guard let eq = line.range(of: "=") else { return nil }
        let name = line[line.startIndex..<eq.lowerBound].trimmingCharacters(in: .whitespaces)
        let body = line[eq.upperBound...].trimmingCharacters(in: .whitespaces)
        let parts = body.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let type = parts.first?.lowercased(), parts.count >= 2 else { return nil }
        var group = ProxyGroup(name: name, type: normalizedGroup(type), members: Array(parts.dropFirst()))
        return group
    }

    // MARK: - 规则行
    // Surge: DOMAIN-SUFFIX,example.com,Proxy
    // QX:    host-suffix,example.com,proxy
    static func parseRuleLine(_ line: String, quantumult: Bool) -> Rule? {
        let parts = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2 else { return nil }
        let rawKind = parts[0].lowercased()

        if rawKind == "final" || rawKind == "match" {
            return Rule(kind: "FINAL", payload: "", policy: parts.last ?? "DIRECT", raw: line)
        }
        guard parts.count >= 3 else { return nil }
        let kind: String
        if quantumult {
            switch rawKind {
            case "host", "host-suffix", "host-keyword", "ip-cidr", "ip-cidr6", "geoip":
                kind = ["host": "DOMAIN", "host-suffix": "DOMAIN-SUFFIX",
                        "host-keyword": "DOMAIN-KEYWORD", "ip-cidr": "IP-CIDR",
                        "ip-cidr6": "IP-CIDR6", "geoip": "GEOIP"][rawKind]!
            default:
                kind = rawKind.uppercased()
            }
        } else {
            kind = rawKind.uppercased()
        }
        let noResolve = parts.contains("no-resolve")
        return Rule(kind: kind, payload: parts[1], policy: parts[2], raw: line, noResolve: noResolve)
    }

    static func normalized(_ t: String) -> String {
        switch t {
        case "socks": return "socks5"
        case "socks5-tls": return "socks5"
        default: return t
        }
    }

    static func normalizedGroup(_ t: String) -> String {
        switch t {
        case "url-test": return "url-test"
        case "fallback": return "fallback"
        case "load-balance": return "load-balance"
        default: return "select"
        }
    }
}
