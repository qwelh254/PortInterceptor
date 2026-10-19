//
//  PortInterceptorApp.swift
//  应用入口
//

import SwiftUI

@main
struct PortInterceptorApp: App {
    @StateObject private var store = ConfigStore()
    @StateObject private var tunnel = TunnelManager()
    @StateObject private var proxy = ProxyServerManager()

    init() {
        // 全局深色外观（与截图一致）
        UIView.appearance().overrideUserInterfaceStyle = .dark
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(tunnel)
                .environmentObject(proxy)
                .preferredColorScheme(.dark)
        }
    }
}
