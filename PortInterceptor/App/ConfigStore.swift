//
//  ConfigStore.swift
//  已导入配置的本地存储（JSON 持久化到 App 沙盒）
//

import Foundation

@MainActor
public final class ConfigStore: ObservableObject {
    @Published public var configs: [ProxyConfig] = []
    @Published public var selectedConfigID: UUID?

    private let saveURL: URL
    private let selectedIDKey = "selectedConfigID"

    public init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        saveURL = dir.appendingPathComponent("configs.json")
        load()
    }

    public func add(_ config: ProxyConfig) {
        configs.removeAll { $0.name == config.name }
        configs.insert(config, at: 0)
        if selectedConfigID == nil { selectedConfigID = config.id }
        save()
    }

    public func remove(at offsets: IndexSet) {
        configs.remove(atOffsets: offsets)
        if let id = selectedConfigID, !configs.contains(where: { $0.id == id }) {
            selectedConfigID = configs.first?.id
        }
        save()
    }

    public func select(_ id: UUID) {
        selectedConfigID = id
        save()
    }

    public var selected: ProxyConfig? {
        guard let id = selectedConfigID else { return configs.first }
        return configs.first { $0.id == id } ?? configs.first
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let saved = try? JSONDecoder.configDecoder.decode([ProxyConfig].self, from: data)
        else { return }
        configs = saved
        // 恢复用户上次选中的配置（而非默认第一个）
        if let idStr = UserDefaults.standard.string(forKey: selectedIDKey),
           let id = UUID(uuidString: idStr),
           saved.contains(where: { $0.id == id }) {
            selectedConfigID = id
        } else {
            selectedConfigID = saved.first?.id
        }
    }

    private func save() {
        guard let data = try? JSONEncoder.configEncoder.encode(configs) else { return }
        try? data.write(to: saveURL, options: .atomic)
        if let id = selectedConfigID {
            UserDefaults.standard.set(id.uuidString, forKey: selectedIDKey)
        }
    }
}

public extension JSONDecoder {
    static var configDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

public extension JSONEncoder {
    static var configEncoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }
}
