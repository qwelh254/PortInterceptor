//
//  ProxyNode.swift
//  代理节点模型：ss / vmess / vless / trojan / http / socks5 / hysteria2 等
//

import Foundation

public struct ProxyNode: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var name: String
    public var type: String            // ss, vmess, vless, trojan, http, https, socks5, hysteria2 ...
    public var server: String
    public var port: Int

    // 通用认证 / 传输参数（不同协议用到的字段不同，全部可选）
    public var password: String?
    public var cipher: String?         // Shadowsocks 加密方法
    public var uuid: String?
    public var alterId: Int?
    public var tls: Bool?
    public var allowInsecure: Bool?
    public var sni: String?
    public var fingerprint: String?
    public var network: String?        // tcp / ws / grpc / quic
    public var wsPath: String?
    public var wsHost: String?
    public var grpcServiceName: String?
    public var flow: String?
    public var udp: Bool?
    public var username: String?
    public var rawURI: String?         // 原始分享链接（订阅导入时保留）

    public init(name: String, type: String, server: String, port: Int) {
        self.name = name
        self.type = type
        self.server = server
        self.port = port
    }

    /// 协议类型的中文展示名
    public var typeDisplayName: String {
        switch type.lowercased() {
        case "ss":           return "Shadowsocks"
        case "vmess":        return "VMess"
        case "vless":        return "VLESS"
        case "trojan":       return "Trojan"
        case "http":         return "HTTP"
        case "https":        return "HTTPS"
        case "socks5":       return "SOCKS5"
        case "hysteria2", "hy2": return "Hysteria2"
        case "direct":       return "直连"
        case "reject":       return "拒绝"
        default:             return type.uppercased()
        }
    }
}
