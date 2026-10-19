//
//  ConfigImporter.swift
//  统一导入入口：传入文本 / 文件 URL / 订阅链接，自动识别格式并解析
//

import Foundation

public enum ConfigImporter {

    public enum ImportError: LocalizedError {
        case network(String)
        public var errorDescription: String? {
            switch self {
            case .network(let m): return "下载订阅失败：\(m)"
            }
        }
    }

    /// 解析配置文本（剪贴板 / 文件内容 / 下载结果都走这里）
    @MainActor
    public static func parseText(_ raw: String, suggestedName: String? = nil) throws -> ProxyConfig {
        let format = try ConfigFormatDetector.detect(raw)
        switch format {
        case .clash:
            return try ClashConfigParser.parse(raw, name: suggestedName)
        case .surge:
            return try SurgeConfigParser.parse(raw, format: .surge, name: suggestedName)
        case .quantumultX:
            return try SurgeConfigParser.parse(raw, format: .quantumultX, name: suggestedName)
        case .subscription:
            return SubscriptionParser.parse(raw, name: suggestedName)
        }
    }

    /// 读取本地文件（用户从“文件” App 选择后拿到的 URL）
    @MainActor
    public static func parseFile(at url: URL) throws -> ProxyConfig {
        // 需要访问安全范围资源
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        let text = try String(contentsOf: url, encoding: .utf8)
        return try parseText(text, suggestedName: url.deletingPathExtension().lastPathComponent)
    }

    /// 下载远程订阅链接并解析
    public static func parseRemote(urlString: String) async throws -> ProxyConfig {
        guard let url = URL(string: urlString) else {
            throw ImportError.network("订阅链接格式不正确")
        }
        var request = URLRequest(url: url)
        request.setValue("clash.meta/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            // 有些机场返回 UTF-8 文本，有些直接返回 Base64
            guard let text = String(data: data, encoding: .utf8) else {
                throw ImportError.network("返回内容不是文本")
            }
            return try await MainActor.run {
                try parseText(text, suggestedName: url.host() ?? "远程订阅")
            }
        } catch let e as ImportError {
            throw e
        } catch {
            throw ImportError.network(error.localizedDescription)
        }
    }
}
