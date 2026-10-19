//
//  PacketTunnelProvider.swift
//  网络扩展主类：创建虚拟网卡、接管系统流量、按规则分流
//
//  ─────────────────────────────────────────────────────────────
//  启用方法（需要付费 Apple 开发者账号）：
//  1. Xcode → File → New → Target → Network Extension，选 "Packet Tunnel Provider"
//  2. Product Name 填 PacketTunnel，Bundle ID 填
//     com.example.PortInterceptor.PacketTunnel（与主 App TunnelManager 中一致）
//  3. 删掉模板生成的源码，把本文件夹（PacketTunnel）三个文件加入该 target
//  4. 主 App 与扩展都开启 Network Extensions 能力，勾选 Packet Tunnel
//  5. 主 App 开启 App Groups，扩展通过 App Group 共享配置（本示例直接用
//     providerConfiguration 传递配置，故不做强制要求）
//  ─────────────────────────────────────────────────────────────
//

import NetworkExtension
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {

    private let log = OSLog(subsystem: "com.example.PortInterceptor.PacketTunnel",
                           category: "tunnel")
    private var matcher: SharedRuleMatcher?
    private var localProxy: LocalHTTPProxy?

    /// 本地代理监听端口（TUN 还原出的连接转发到这里）
    private let proxyPort: UInt16 = 1081

    // MARK: - 启动
    override func startTunnel(options: [String: NSObject]?,
                             completionHandler: @escaping (Error?) -> Void) {
        os_log("PacketTunnel starting…", log: log, type: .info)

        // 1) 读取主 App 传入的配置
        let configData = (protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["configData"] as? Data
        let ruleMatcher = SharedRuleMatcher(configData: configData)
        self.matcher = ruleMatcher

        // 2) 配置虚拟网卡（TUN）
        //    198.18.0.0/15 是 RFC2544 保留段，Surge/Clash 均用它做 Fake-IP
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "198.18.0.1")
        networkSettings.ipv4Settings = {
            let ipv4 = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.255.0"])
            ipv4.includedRoutes = [NEIPv4Route.default()]
            return ipv4
        }()
        // DNS 用公共解析器，避免 DNS 泄漏
        networkSettings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        networkSettings.mtu = 1500

        setTunnelNetworkSettings(networkSettings) { [weak self] error in
            if let error = error {
                os_log("设置虚拟网卡失败: %{public}@", log: self?.log ?? .default, type: .error,
                       error.localizedDescription)
                completionHandler(error)
                return
            }
            self?.startLocalProxy(matcher: ruleMatcher)
            self?.startPacketLoop()
            completionHandler(nil)
        }
    }

    // MARK: - 停止
    override func stopTunnel(with reason: NEProviderStopReason,
                             completionHandler: @escaping () -> Void) {
        os_log("PacketTunnel stopping: %d", log: log, type: .info, reason.rawValue)
        localProxy?.stop()
        completionHandler()
    }

    // MARK: - 本地代理
    private func startLocalProxy(matcher: SharedRuleMatcher) {
        // 付费版：从配置中选出当前节点并按协议构造上游。
        // 这里先启动 HTTP 代理框架；DIRECT / REJECT 规则已可完整工作。
        // 若启用了 HTTP 类型代理节点，可传入 upstream: (host, port)。
        let proxy = LocalHTTPProxy(matcher: matcher, upstream: nil)
        do {
            try proxy.start(port: proxyPort)
            localProxy = proxy
            os_log("本地代理已启动，端口 %d", log: log, type: .info, proxyPort)
        } catch {
            os_log("本地代理启动失败: %{public}@", log: log, type: .error,
                   error.localizedDescription)
        }
    }

    // MARK: - TUN 读包循环
    //  这里从虚拟网卡读取原始 IP 包。要把 IP 包还原为 TCP/UDP 连接并转发到
    //  本地代理，需要一个用户态 TCP/IP 协议栈。工程实践有两种：
    //   1) 集成 lwip（C 库，最常见，Clash 核心/tun2socks 都是这一类）
    //      对接点：在 readPackets 中把 packet 写入 lwip 的 tun 输入接口；
    //      lwip 回调新建 TCP 连接时，再用 NWConnection 连到 127.0.0.1:proxyPort；
    //   2) 直接集成 sing-box / Xray 的 Go 核心（gomobile 编译为 xcframework），
    //      由 Go 核心处理 TUN + 全部协议（SS/VMess/Trojan/Hysteria2），
    //      本扩展只需把包喂给 Go 核心，这是最省事、协议覆盖最全的方案。
    private func startPacketLoop() {
        packetFlow.readPackets { [weak self] packets, _ in
            // 每个 packet 是一个 Data，为完整的 IPv4/IPv6 数据报
            for packet in packets {
                self?.handleRawPacket(packet)
            }
            // 继续读下一批
            self?.startPacketLoop()
        }
    }

    private func handleRawPacket(_ packet: Data) {
        // ┌─ 教学示例：解析 IPv4 头，取出协议号与四元组 ────────────────
        guard packet.count >= 20 else { return }
        let version = packet[0] >> 4
        guard version == 4 else {
            // IPv6：首字节 0x60，付费版可同样解析
            return
        }
        let ihl = Int(packet[0] & 0x0F) * 4
        let proto = packet[9]              // 6 = TCP, 17 = UDP
        let src = ipv4(packet, 12)
        let dst = ipv4(packet, 16)
        os_log("截获 IP 包 %@ -> %@ proto=%d ihl=%d",
               log: log, type: .debug, src, dst, Int(proto), ihl)

        // TODO（付费版）：
        //  · 将 packet 送入 lwip / tun2socks，由其完成 TCP 握手与流重组
        //  · 对还原出的目标域名做 SharedRuleMatcher 判定
        //  · DIRECT -> NWConnection 直连目标；REJECT -> 丢弃；
        //    PROXY   -> 连接本地代理 127.0.0.1:proxyPort（或直接走协议栈）
        //  · 回包写入 packetFlow.writePackets，并维护 NAT 映射
    }

    private func ipv4(_ data: Data, _ offset: Int) -> String {
        return "\(data[offset]).\(data[offset + 1]).\(data[offset + 2]).\(data[offset + 3])"
    }
}
