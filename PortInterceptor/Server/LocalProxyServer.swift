//
//  LocalProxyServer.swift
//  App 内本地 HTTP 代理服务器（Network.framework，无第三方依赖）
//  监听 127.0.0.1:8888，配合「设置 → 无线局域网 → 配置代理 → 手动」使用
//
//  支持：
//   · CONNECT host:port（HTTPS 隧道，按域名分流）
//   · 普通 HTTP 请求（按 Host 头转发；验证网址返回内置门户页）
//  动作：直连 / 拦截（REJECT）/ 走代理（免费账号无加密节点时回退直连）
//

import Foundation
import Network

public final class LocalProxyServer: @unchecked Sendable {
    private var listener: NWListener?
    private var matcher: LocalRuleMatcher
    private let stats: ProxyStats
    private let queue = DispatchQueue(label: "com.example.PortInterceptor.localProxy",
                                     attributes: .concurrent)
    private let port: UInt16
    private let configInfo: (name: String, nodes: Int, rules: Int)

    public init(port: UInt16,
                matcher: LocalRuleMatcher,
                stats: ProxyStats,
                configName: String,
                nodeCount: Int,
                ruleCount: Int) {
        self.port = port
        self.matcher = matcher
        self.stats = stats
        self.configInfo = (configName, nodeCount, ruleCount)
    }

    public func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        // 仅绑定到本机回环，避免外部设备连接
        params.requiredLocalEndpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host("127.0.0.1"),
            port: NWEndpoint.Port(rawValue: port)!)
        let listener = try NWListener(using: params)
        listener.newConnectionHandler = { [weak self] conn in
            self?.queue.async { self?.handleClient(conn) }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - 切换拦截开关（重建匹配器）
    public func updateMatcher(_ newMatcher: LocalRuleMatcher) {
        queue.async(flags: .barrier) { self.matcher = newMatcher }
    }

    // MARK: - 客户端连接
    private func handleClient(_ client: NWConnection) {
        client.start(queue: queue)
        // 捕获当前匹配器的本地引用，避免与 updateMatcher（barrier）发生竞争
        let matcher = self.matcher
        receiveRequest(client) { [weak self] result in
            guard let self, let result = result else { client.cancel(); return }
            let (lines, leftover) = result
            guard let firstLine = lines.first else { client.cancel(); return }
            let parts = firstLine.split(separator: " ", maxSplits: 2).map(String.init)
            guard parts.count >= 2 else { client.cancel(); return }

            if parts[0].uppercased() == "CONNECT" {
                self.processConnect(client: client, matcher: matcher,
                                    target: parts[1], leftover: leftover)
            } else {
                self.processPlainHTTP(client: client,
                                      matcher: matcher,
                                      method: parts[0],
                                      target: parts[1],
                                      lines: lines,
                                      leftover: leftover)
            }
        }
    }

    // MARK: - HTTPS CONNECT
    private func processConnect(client: NWConnection,
                                matcher: LocalRuleMatcher,
                                target: String,
                                leftover: Data) {
        let host = String(target.split(separator: ":")[0])
        let port = NWEndpoint.Port(target.split(separator: ":").count == 2
                                   ? String(target.split(separator: ":")[1])
                                   : "443") ?? .https
        let decision = matcher.decision(for: host)
        stats.record(decision.outcome)

        switch decision {
        case .blocked:
            sendBlockedTunnel(client)
        case .direct, .proxied:
            let remote = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
            remote.start(queue: queue)
            let ok = "HTTP/1.1 200 Connection Established\r\n\r\n".data(using: .utf8)!
            client.send(content: ok, completion: .contentProcessed { _ in })
            if !leftover.isEmpty {
                remote.send(content: leftover, completion: .contentProcessed { _ in })
            }
            bridge(client, remote)
        }
    }

    // MARK: - 普通 HTTP
    private func processPlainHTTP(client: NWConnection,
                                  matcher: LocalRuleMatcher,
                                  method: String,
                                  target: String,
                                  lines: [String],
                                  leftover: Data) {
        guard let hostLine = lines
            .first(where: { $0.lowercased().hasPrefix("host:") })?
            .dropFirst(5).trimmingCharacters(in: .whitespaces) else {
            client.cancel(); return
        }
        let cleanedHost = hostLine.contains(":")
            ? String(hostLine.split(separator: ":")[0])
            : hostLine
        let port = NWEndpoint.Port(hostLine.contains(":")
                                   ? String(hostLine.split(separator: ":")[1])
                                   : "80") ?? .http

        // 门户验证：访问验证网址时返回内置「验证成功」页面
        if PortalPage.isVerification(host: cleanedHost) {
            stats.record(.direct)
            sendPortal(client)
            return
        }

        let decision = matcher.decision(for: cleanedHost)
        stats.record(decision.outcome)

        switch decision {
        case .blocked:
            sendBlockedHTTP(client, host: cleanedHost)
        case .direct, .proxied:
            let remote = NWConnection(host: NWEndpoint.Host(cleanedHost),
                                      port: port, using: .tcp)
            remote.start(queue: queue)
            var request = Data()
            request.append(lines.joined(separator: "\r\n").data(using: .utf8)!)
            request.append(Data("\r\n\r\n".utf8))
            if !leftover.isEmpty { request.append(leftover) }
            remote.send(content: request, completion: .contentProcessed { _ in })
            bridge(client, remote)
        }
    }

    // MARK: - 响应
    private func sendPortal(_ client: NWConnection) {
        let body = PortalPage.html(configName: configInfo.name,
                                   nodes: configInfo.nodes,
                                   rules: configInfo.rules,
                                   stats: stats.snapshot(),
                                   port: self.port)
        let bodyData = body.data(using: .utf8)!
        let head = "HTTP/1.1 200 OK\r\n"
            + "Content-Type: text/html; charset=utf-8\r\n"
            + "Content-Length: \(bodyData.count)\r\n"
            + "Cache-Control: no-store\r\n"
            + "Connection: close\r\n\r\n"
        var data = head.data(using: .utf8)!
        data.append(bodyData)
        client.send(content: data, completion: .contentProcessed { _ in
            client.cancel()
        })
    }

    private func sendBlockedHTTP(client: NWConnection, host: String) {
        let body = """
        <!DOCTYPE html><html lang="zh-CN"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>已拦截</title>
        <style>body{font-family:-apple-system,"PingFang SC",sans-serif;background:#0d1117;color:#e6edf3;
        display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0;padding:24px}
        .c{text-align:center;max-width:420px}.i{font-size:56px}h1{font-size:22px;margin:14px 0 8px}
        p{color:#9aa7b4;font-size:14px;line-height:1.7}</style></head>
        <body><div class="c"><div class="i">🚫</div><h1>该连接已被拦截</h1>
        <p>域名 <b>\(host)</b> 命中了拦截规则（REJECT）。<br>
        如需放行，请在「连接」页关闭拦截开关，或调整配置规则。</p></div></body></html>
        """
        let bodyData = body.data(using: .utf8)!
        let head = "HTTP/1.1 403 Forbidden\r\n"
            + "Content-Type: text/html; charset=utf-8\r\n"
            + "Content-Length: \(bodyData.count)\r\n"
            + "Connection: close\r\n\r\n"
        var data = head.data(using: .utf8)!
        data.append(bodyData)
        client.send(content: data, completion: .contentProcessed { _ in client.cancel() })
    }

    private func sendBlockedTunnel(_ client: NWConnection) {
        // HTTPS 拦截：直接断开隧道（浏览器报连接失败），避免泄露
        let resp = "HTTP/1.1 503 Service Unavailable\r\nConnection: close\r\n\r\n"
        client.send(content: resp.data(using: .utf8),
                    completion: .contentProcessed { _ in client.cancel() })
    }

    // MARK: - 双向桥接
    private func bridge(_ a: NWConnection, _ b: NWConnection) {
        relay(a, to: b)
        relay(b, to: a)
    }

    private func relay(_ from: NWConnection, to: NWConnection) {
        from.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, complete, error in
            guard let self else { from.cancel(); to.cancel(); return }
            if let data = data, !data.isEmpty {
                to.send(content: data, completion: .contentProcessed { _ in
                    self.relay(from, to: to)
                })
            }
            if complete || error != nil {
                from.cancel(); to.cancel()
            }
        }
    }

    // MARK: - 读取请求头（返回请求行数组 + 多余的 body 字节）
    private func receiveRequest(_ conn: NWConnection,
                                completion: @escaping (([String], Data)?) -> Void) {
        var buffer = Data()
        func read() {
            conn.receive(minimumIncompleteLength: 1, maximumLength: 16384) { data, _, complete, error in
                if let data = data { buffer.append(data) }
                if let range = buffer.range(of: Data("\r\n\r\n".utf8)) {
                    let headerData = buffer.subdata(in: 0..<range.lowerBound)
                    let leftover = buffer.subdata(in: range.upperBound..<buffer.endIndex)
                    let text = String(data: headerData, encoding: .utf8) ?? ""
                    completion((text.components(separatedBy: "\r\n"), leftover))
                    return
                }
                if complete || error != nil {
                    if buffer.isEmpty { completion(nil); return }
                    let text = String(data: buffer, encoding: .utf8) ?? ""
                    completion((text.components(separatedBy: "\r\n"), Data()))
                    return
                }
                read()
            }
        }
        read()
    }
}

// MARK: - 决策 -> 统计结果
extension LocalRuleMatcher.Decision {
    var outcome: ProxyStats.Outcome {
        switch self {
        case .blocked: return .blocked
        case .direct:  return .direct
        case .proxied: return .proxied
        }
    }
}
