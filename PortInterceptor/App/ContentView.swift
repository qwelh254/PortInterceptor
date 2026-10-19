//
//  ContentView.swift
//  底部三个标签：配置 / 规则 / 连接（液态玻璃）
//

import SwiftUI

struct ContentView: View {
    init() {
        // 让 TabBar 透明，露出玻璃背景
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack {
            GlassBackground()
            TabView {
                ConfigListView()
                    .tabItem { Label("配置", systemImage: "archivebox.fill") }
                RuleTestView()
                    .tabItem { Label("规则", systemImage: "shield.fill") }
                ConnectionView()
                    .tabItem { Label("连接", systemImage: "bolt.fill") }
            }
            .tint(GlassTheme.accent)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ConfigStore())
        .environmentObject(TunnelManager())
        .environmentObject(ProxyServerManager())
}
