//
//  ProxyGroup.swift
//  策略组模型：select(手动选择) / url-test(自动测速) / fallback / load-balance
//

import Foundation

public struct ProxyGroup: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var name: String
    public var type: String            // select / url-test / fallback / load-balance
    public var members: [String]       // 成员：节点名或其他策略组名
    public var testURL: String?
    public var interval: Int?          // 测速间隔（秒）

    public init(name: String, type: String, members: [String]) {
        self.name = name
        self.type = type
        self.members = members
    }

    public var typeDisplayName: String {
        switch type.lowercased() {
        case "select":        return "手动选择"
        case "url-test":      return "自动测速"
        case "fallback":      return "故障转移"
        case "load-balance":  return "负载均衡"
        default:              return type
        }
    }
}
