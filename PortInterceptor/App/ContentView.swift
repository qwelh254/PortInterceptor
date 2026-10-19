//
//  ContentView.swift
//  底部五个标签：配置 / 活动 / 连接 / 统计 / 设置（液态玻璃）
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
                ActivityView()
                    .tabItem { Label("活动", systemImage: "waveform.path.ecg") }
                ConnectionView()
                    .tabItem { Label("连接", systemImage: "bolt.fill") }
                StatsView()
                    .tabItem { Label("统计", systemImage: "chart.pie.fill") }
                SettingsView()
                    .tabItem { Label("设置", systemImage: "gearshape.fill") }
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
