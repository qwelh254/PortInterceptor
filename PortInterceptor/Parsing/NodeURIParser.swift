//
//  NodeURIParser.swift
//  解析单条节点分享链接：ss:// vmess:// vless:// trojan:// socks5:// http://
//

import Foundation

public enum NodeURIParser {

    public enum ParseError: LocalizedError {
        case unsupported(String)
        public var errorDescription: String? {
            switch self {
            case .unsupported(let s): return "不支持的节点链接：\(s.prefix(40))"
            }
        }
    }

    /// 解析一行节点 URI，失败返回 nil
    public static func parse(_ line: String) -> ProxyNode? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let range = trimmed.range(of: "://") else { return nil }
        let scheme = String(trimmed[trimmed.startIndex..<range.lowerBound]).lowercased()
        switch scheme {
        case "ss":         return parseShadowsocks(trimmed)
        case "vmess":      return parseVMess(trimmed)
        case "vless":      return parseVLESS(trimmed)
        case "trojan":     return parseTrojan(trimmed)
        case "socks", "socks5": return parseSocksOrHTTP(trimmed, type: "socks5")
        case "http":       return parseSocksOrHTTP(trimmed, type: "http")
        case "https":      return parseSocksOrHTTP(trimmed, type: "https")
        case "hysteria2", "hy2": return parseHysteria2(trimmed)
        default:           return nil
        }
    }

    // MARK: - Shadowsocks (SIP002 / 老式整体 Base64)
    static func parseShadowsocks(_ uri: String) -> ProxyNode? {
        let body = String(uri.dropFirst("ss://".count))
        // 去掉 fragment / query
        let mainPart = body.split(separator: "#").first.map(String.init) ?? body
        let name = fragmentName(in: body)

        // 形式 A：ss://base64(method:password)@host:port
        if let at = mainPart.range(of: "@") {
            let userInfo = String(mainPart[mainPart.startIndex..<at.lowerBound])
                .removingPercentEncoding?
                .replacingOccurrences(of: "%3D", with: "=")
                ?? String(mainPart[mainPart.startIndex..<at.lowerBound])
            let hostPart = String(mainPart[at.upperBound...]).split(separator: "?").first.map(String.init) ?? ""
            guard let decoded = base64Flexible(userInfo) else { return nil }
            let parts = decoded.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let (host, port) = splitHostPort(hostPart) else { return nil }
            var node = ProxyNode(name: name ?? host, type: "ss", server: host, port: port)
            node.cipher = parts[0]
            node.password = parts[1]
            node.rawURI = uri
            return node
        }

        // 形式 B：ss://base64(method:password@host:port)
        let cleaned = mainPart.split(separator: "?").first.map(String.init) ?? mainPart
        guard let decoded = base64Flexible(cleaned),
              let at = decoded.range(of: "@") else { return nil }
        let auth = String(decoded[decoded.startIndex..<at.lowerBound])
        let hostPart = String(decoded[at.upperBound...])
        let authParts = auth.split(separator: ":", maxSplits: 1).map(String.init)
        guard authParts.count == 2,
              let (host, port) = splitHostPort(hostPart) else { return nil }
        var node = ProxyNode(name: name ?? host, type: "ss", server: host, port: port)
        node.cipher = authParts[0]
        node.password = authParts[1]
        node.rawURI = uri
        return node
    }

    // MARK: - VMess（Base64 包裹的 JSON）
    static func parseVMess(_ uri: String) -> ProxyNode? {
        let body = String(uri.dropFirst("vmess://".count))
        guard let data = base64FlexibleData(body),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let host = json["add"] as? String,
              let portAny = json["port"],
              let port = Int("\(portAny)") else { return nil }
        var node = ProxyNode(name: (json["ps"] as? String) ?? host,
                             type: "vmess", server: host, port: port)
        node.uuid = json["id"] as? String
        node.alterId = Int("\(json["aid"] ?? 0)")
        node.cipher = (json["scy"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "auto"
        node.network = json["net"] as? String
        node.wsPath = json["path"] as? String
        node.wsHost = json["host"] as? String
        node.tls = (json["tls"] as? String) == "tls"
        node.rawURI = uri
        return node
    }

    // MARK: - VLESS / Trojan（URI 参数风格）
    static func parseVLESS(_ uri: String) -> ProxyNode? {
        guard let comps = URLComponents(string: uri),
              let host = comps.host, let port = comps.port else { return nil }
        var node = ProxyNode(name: fragmentName(in: uri) ?? host,
                             type: "vless", server: host, port: port)
        node.uuid = comps.user
        let q = comps.queryItemsDictionary
        node.network = q["type"]
        node.tls = (q["security"] == "tls" || q["security"] == "reality")
        node.sni = q["sni"]
        node.fingerprint = q["fp"]
        node.wsPath = q["path"]
        node.wsHost = q["host"]
        node.flow = q["flow"]
        node.rawURI = uri
        return node
    }

    static func parseTrojan(_ uri: String) -> ProxyNode? {
        guard let comps = URLComponents(string: uri),
              let host = comps.host, let port = comps.port else { return nil }
        var node = ProxyNode(name: fragmentName(in: uri) ?? host,
                             type: "trojan", server: host, port: port)
        node.password = comps.user
        let q = comps.queryItemsDictionary
        node.network = q["type"]
        node.tls = true
        node.sni = q["sni"] ?? q["peer"]
        node.wsPath = q["path"]
        node.allowInsecure = q["allowInsecure"] == "1"
        node.rawURI = uri
        return node
    }

    // MARK: - SOCKS5 / HTTP
    static func parseSocksOrHTTP(_ uri: String, type: String) -> ProxyNode? {
        guard let comps = URLComponents(string: uri),
              let host = comps.host, let port = comps.port else { return nil }
        var node = ProxyNode(name: fragmentName(in: uri) ?? host,
                             type: type, server: host, port: port)
        node.username = comps.user
        node.password = comps.password
        node.tls = (type == "https") || comps.queryItemsDictionary["tls"] == "1"
        node.rawURI = uri
        return node
    }

    // MARK: - Hysteria2
    static func parseHysteria2(_ uri: String) -> ProxyNode? {
        guard let comps = URLComponents(string: uri),
              let host = comps.host, let port = comps.port else { return nil }
        var node = ProxyNode(name: fragmentName(in: uri) ?? host,
                             type: "hysteria2", server: host, port: port)
        node.password = comps.user ?? comps.password
        let q = comps.queryItemsDictionary
        node.sni = q["sni"]
        node.allowInsecure = q["insecure"] == "1"
        node.rawURI = uri
        return node
    }

    // MARK: - 工具
    static func splitHostPort(_ s: String) -> (String, Int)? {
        let parts = s.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let port = Int(parts[1]) else { return nil }
        return (parts[0], port)
    }

    static func fragmentName(in uri: String) -> String? {
        guard let comps = URLComponents(string: uri),
              let frag = comps.fragment?.removingPercentEncoding,
              !frag.isEmpty else { return nil }
        return frag
    }

    static func base64Flexible(_ s: String) -> String? {
        guard let data = base64FlexibleData(s) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func base64FlexibleData(_ s: String) -> Data? {
        var cleaned = s.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let stripped = cleaned.filter { !$0.isWhitespace }
        if stripped.count % 4 != 0 {
            cleaned = stripped + String(repeating: "=", count: 4 - stripped.count % 4)
        } else {
            cleaned = stripped
        }
        return Data(base64Encoded: cleaned, options: .ignoreUnknownCharacters)
    }
}

extension URLComponents {
    var queryItemsDictionary: [String: String] {
        var dict: [String: String] = [:]
        queryItems?.forEach { dict[$0.name] = $0.value }
        return dict
    }
}
