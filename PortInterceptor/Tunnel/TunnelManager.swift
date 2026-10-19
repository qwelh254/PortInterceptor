//
//  TunnelManager.swift
//  隧道开关：封装 Network Extension 的 NETunnelProviderManager
//
//  注意：真正启动 PacketTunnel 扩展需要付费 Apple 开发者账号开启 Network Extensions 权限。
//  免费账号下调用 start() 会失败，界面会给出明确提示（这是苹果的限制，不是 Bug）。
//

import Foundation
import NetworkExtension

@MainActor
public final class TunnelManager: NSObject, ObservableObject {
    public enum State: Equatable {
        case off
        case connecting
        case on
        case error(String)
    }

    @Published public var state: State = .off
    private var manager: NETunnelProviderManager?

    /// 扩展的 Bundle ID，需要与付费账号下新建的 Network Extension target 一致
    public static let extensionBundleID = "com.example.PortInterceptor.PacketTunnel"

    public override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(statusDidChange(_:)),
            name: .NEVPNStatusDidChange, object: nil)
    }

    public func start(config: ProxyConfig) {
        state = .connecting
        Task {
            do {
                let managers = try await NETunnelProviderManager.loadAllManagers()
                let manager = managers.first ?? NETunnelProviderManager()

                let proto = NETunnelProviderProtocol()
                proto.providerBundleIdentifier = Self.extensionBundleID
                proto.serverAddress = config.name
                // 把当前配置 JSON 传给扩展
                if let data = try? JSONEncoder.configEncoder.encode(config) {
                    proto.providerConfiguration = ["configData": data]
                }
                manager.protocolConfiguration = proto
                manager.localizedDescription = config.name
                manager.isEnabled = true
                try await manager.saveToPreferences()
                try manager.connection.startVPNTunnel()
                self.manager = manager
                self.state = .on
            } catch {
                self.state = .error(friendlyError(error))
            }
        }
    }

    public func stop() {
        manager?.connection.stopVPNTunnel()
        state = .off
    }

    @objc private func statusDidChange(_ note: Notification) {
        guard let session = note.object as? NETunnelProviderSession else { return }
        Task { @MainActor in
            switch session.status {
            case .connected:    state = .on
            case .connecting:   state = .connecting
            case .disconnected, .invalid:
                state = .off
            case .disconnecting:
                state = .connecting
            @unknown default:   state = .off
            }
        }
    }

    private func friendlyError(_ error: Error) -> String {
        let msg = error.localizedDescription
        let ns = error as NSError
        if ns.domain == (NEVPNErrorDomain as String)
            || msg.lowercased().contains("permission")
            || msg.lowercased().contains("entitlement")
            || msg.lowercased().contains("not permitted")
            || msg.lowercased().contains("configuration is invalid")
            || msg.lowercased().contains("could not start") {
            return "无法启动隧道：免费 Apple ID 没有 Network Extension 权限。请在 README 指引下使用付费开发者账号（99 美元/年）开启后再试。"
        }
        return "启动失败：\(msg)"
    }
}
