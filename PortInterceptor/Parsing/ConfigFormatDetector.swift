//
//  ConfigFormatDetector.swift
//  自动识别配置格式：Clash / Surge / Quantumult X / Base64 订阅
//

import Foundation

public enum ConfigFormatDetector {

    /// 识别结果
    public enum Detection {
        case clash
        case surge
        case quantumultX
        case subscription
    }

    public struct DetectionError: LocalizedError {
        public let message: String
        public var errorDescription: String? { message }
    }

    /// 自动识别一段配置文本的格式
    public static func detect(_ raw: String) throws -> Detection {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw DetectionError(message: "配置内容为空")
        }

        // 1) 整体可能是 Base64 包裹的订阅（机场订阅常见）
        if let decoded = base64DecodeIfPossible(text),
           decoded.range(of: "://") != nil {
            return .subscription
        }

        let lower = text.lowercased()
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // 2) Clash YAML（兼容 Clash.Meta / Mihomo / Stash / Egern）：
        //    包含 proxies: / proxy-groups: / rules: / mixed-port: 等特征
        let clashKeys = ["proxies:", "proxy-groups:", "proxy_groups:",
                         "rules:", "mixed-port:", "mixed_port:", "port:",
                         "external-controller:", "rule-providers:", "proxy-providers:"]
        let clashHits = lines.filter { line in
            clashKeys.contains { line.lowercased().hasPrefix($0) }
        }.count
        if clashHits >= 2 || (clashHits >= 1 && lower.contains("proxies")) {
            return .clash
        }

        // 3) Surge / Loon：[General] [Proxy] [Rule]
        let surgeSections = ["[general]", "[proxy]", "[rule]", "[proxy group]", "[host]", "[url rewrite]"]
        if lines.contains(where: { surgeSections.contains($0.lowercased()) }) {
            return .surge
        }

        // 4) Quantumult X
        let qxSections = ["[server_local]", "[server_remote]", "[filter_local]",
                          "[filter_remote]", "[rewrite_local]", "[rewrite_remote]", "[general]"]
        if lines.contains(where: { qxSections.contains($0.lowercased()) }) {
            // [general] 两者都有，进一步用 Quantumult 特有段判断
            if lines.contains(where: { $0.lowercased().hasPrefix("[server") || $0.lowercased().hasPrefix("[filter") || $0.lowercased().hasPrefix("[rewrite") }) {
                return .quantumultX
            }
        }

        // 5) 裸订阅：大部分行是 scheme:// 形式的节点链接
        let uriLines = lines.filter { line in
            ["ss://", "vmess://", "vless://", "trojan://", "hysteria2://", "hy2://",
             "socks5://", "socks://", "http://", "https://"]
                .contains { line.lowercased().hasPrefix($0) }
        }
        if !uriLines.isEmpty && Double(uriLines.count) >= Double(lines.count) * 0.5 {
            return .subscription
        }

        throw DetectionError(message: """
        无法识别配置格式。目前支持：
        · Clash / Clash.Meta / Mihomo / Stash / Egern（YAML）
        · Surge / Loon / Shadowrocket（.conf）
        · Quantumult X（.conf）
        · Base64 节点订阅（ss://、vmess://、vless://、trojan://、hysteria2:// 等链接）
        """)
    }

    /// 尝试把字符串当 Base64 解码；失败或解码结果不像文本则返回 nil
    public static func base64DecodeIfPossible(_ text: String) -> String? {
        // 去掉所有空白与换行
        var cleaned = text.unicodeScalars
            .filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
            .map(String.init)
            .joined()
        guard cleaned.count >= 16 else { return nil }
        // 只允许 Base64 / URL-safe Base64 字符（普通 YAML、conf 含 : # [ ] 等会被排除）
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=-_")
        guard cleaned.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        // URL-safe Base64 转标准 Base64
        cleaned = cleaned
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // 补齐 padding
        if cleaned.count % 4 != 0 {
            cleaned += String(repeating: "=", count: 4 - cleaned.count % 4)
        }
        guard let data = Data(base64Encoded: cleaned, options: .ignoreUnknownCharacters),
              let decoded = String(data: data, encoding: .utf8) else { return nil }
        // 解码结果必须包含节点链接 scheme
        return decoded.contains("://") ? decoded : nil
    }
}
