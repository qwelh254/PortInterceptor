//
//  LocalHTTPProxy.swift
//  扩展内的本地 HTTP 代理（Network.framework，无第三方依赖）
//  支持：
//   · CONNECT host:port（HTTPS 隧道）
//   · 普通 HTTP 请求（按 Host 头转发）
//  按规则决定：直连 / 拒绝 / 走上游代理
//
//  说明：这是一个教学级的最小可用代理。TUN 网卡的 IP 包需要通过 lwip 等
//  用户态 TCP 栈还原为连接后转发到本代理（见 PacketTunnelProvider 中的对接点）。
//

import Foundation
import Network

final class LocalHTTPProxy {
    private var listener: NWListener?
    private let matcher: SharedRuleMatcher
    private let queue = DispatchQueue(label: "com.example.PortInterceptor.httpProxy")

    /// 上游代理（HTTP 类型节点）；nil 表示代理流量也直连（演示用）
    private let upstream: (host: String, port: Int)?

    init(matcher: SharedRuleMatcher, upstream: (host: String, port: Int)? = nil) {
        self.matcher = matcher
        self.upstream = upstream
    }

    func start(port: UInt16) throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params,
                                      on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { [weak self] conn in
            self?.queue.async { self?.handleClient(conn) }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - 客户端连接
    private func handleClient(_ client: NWConnection) {
        client.start(queue: queue)
        receiveHeaders(client) { [weak self] headers in
            guard let self, let headers = headers,
                  let firstLine = headers.first else {
                client.cancel(); return
            }
            let requestLine = firstLine.split(separator: " ", maxSplits: 2).map(String.init)
            guard requestLine.count >= 2 else { client.cancel(); return }

            if requestLine[0].uppercased() == "CONNECT" {
                // HTTPS：CONNECT api.example.com:443
                let target = requestLine[1]
                self.processConnect(client: client, target: target)
            } else {
                // HTTP：从 Host 头取目标
                guard let hostLine = headers.first(where: { $0.lowercased().hasPrefix("host:") })?
                    .components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) else {
                    client.cancel(); return
                }
                let path = requestLine[1]
                self.processPlainHTTP(client: client, host: hostLine, headers: headers)
            }
        }
    }

    private func processConnect(client: NWConnection, target: String) {
        let parts = target.split(separator: ":").map(String.init)
        let host = parts[0]
        let port = parts.count == 2 ? (NWEndpoint.Port(parts[1]) ?? .https) : .https
        decide(host: host) { [weak self] action in
            guard let self else { client.cancel(); return }
            switch action {
            case .reject:
                client.cancel()
            case .direct:
                let remote = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
                remote.start(queue: self.queue)
                client.send(content: "HTTP/1.1 200 Connection Established\r\n\r\n".data(using: .utf8),
                            completion: .contentProcessed { _ in })
                self.bridge(client, remote)
            case .proxy:
                // 走 HTTP 代理节点：先对上游 CONNECT，再桥接
                self.connectViaUpstream(target: target) { upstream in
                    guard let upstream else { client.cancel(); return }
                    client.send(content: "HTTP/1.1 200 Connection Established\r\n\r\n".data(using: .utf8),
                                completion: .contentProcessed { _ in })
                    self.bridge(client, upstream)
                }
            }
        }
    }

    private func processPlainHTTP(client: NWConnection, host: String, headers: [String]) {
        let cleanedHost = host.contains(":") ? String(host.split(separator: ":")[0]) : host
        let port = NWEndpoint.Port(host.contains(":") ? String(host.split(separator: ":")[1]) : "80") ?? .http
        decide(host: cleanedHost) { [weak self] action in
            guard let self else { client.cancel(); return }
            switch action {
            case .reject:
                let body = "Blocked by PortInterceptor"
                client.send(content: "HTTP/1.1 403 Forbidden\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)".data(using: .utf8),
                            completion: .contentProcessed { _ in client.cancel() })
            case .direct:
                let remote = NWConnection(host: NWEndpoint.Host(cleanedHost), port: port, using: .tcp)
                remote.start(queue: self.queue)
                var requestData = headers.joined(separator: "\r\n").data(using: .utf8)
                requestData?.append(Data("\r\n\r\n".utf8))
                remote.send(content: requestData,
                            completion: .contentProcessed { _ in })
                self.bridge(client, remote)
            case .proxy:
                self.connectViaUpstream(target: "\(cleanedHost):\(port.rawValue)") { upstream in
                    guard let upstream else { client.cancel(); return }
                    var requestData = headers.joined(separator: "\r\n").data(using: .utf8)
                    requestData?.append(Data("\r\n\r\n".utf8))
                    upstream.send(content: requestData,
                                  completion: .contentProcessed { _ in })
                    self.bridge(client, upstream)
                }
            }
        }
    }

    // MARK: - 规则判定
    private func decide(host: String, completion: @escaping (SharedAction) -> Void) {
        // 去掉端口
        var h = host
        if let r = h.range(of: ":") { h = String(h[h.startIndex..<r.lowerBound]) }
        completion(matcher.action(for: h))
    }

    // MARK: - 上游代理
    private func connectViaUpstream(target: String, completion: @escaping (NWConnection?) -> Void) {
        guard let up = upstream else {
            // 没有配置可用上游节点时，演示环境直接失败（付费版在此接入 SS/VMess 加密连接）
            completion(nil); return
        }
        let conn = NWConnection(host: NWEndpoint.Host(up.host),
                                port: NWEndpoint.Port(rawValue: UInt16(up.port))!,
                                using: .tcp)
        conn.start(queue: queue)
        let handshake = "CONNECT \(target) HTTP/1.1\r\nHost: \(target)\r\n\r\n"
        conn.send(content: handshake.data(using: .utf8), completion: .contentProcessed { _ in })
        self.receiveHeaders(conn) { lines in
            if let status = lines?.first, status.contains("200") {
                completion(conn)
            } else {
                conn.cancel(); completion(nil)
            }
        }
    }

    // MARK: - 双向桥接
    private func bridge(_ a: NWConnection, _ b: NWConnection) {
        relay(a, to: b)
        relay(b, to: a)
    }

    private func relay(_ from: NWConnection, to: NWConnection) {
        from.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                to.send(content: data, completion: .contentProcessed { _ in
                    self.relay(from, to: to)
                })
            }
            if isComplete || error != nil {
                from.cancel(); to.cancel()
            }
        }
    }

    // MARK: - 读取 HTTP 头（直到 \r\n\r\n）
    private func receiveHeaders(_ conn: NWConnection, completion: @escaping ([String]?) -> Void) {
        var buffer = Data()
        func read() {
            conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, isComplete, error in
                if let data = data { buffer.append(data) }
                if let idx = buffer.range(of: Data("\r\n\r\n".utf8)) {
                    let headerData = buffer.subdata(in: 0..<idx.lowerBound)
                    let text = String(data: headerData, encoding: .utf8) ?? ""
                    completion(text.components(separatedBy: "\r\n"))
                    return
                }
                if isComplete || error != nil {
                    completion(nil); return
                }
                read()
            }
        }
        read()
    }
}
