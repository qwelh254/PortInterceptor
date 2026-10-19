//
//  GlassBackground.swift
//  液态玻璃背景：深色基底 + 多层彩色光斑（缓慢漂浮），为玻璃卡片提供折射内容
//

import SwiftUI

struct GlassBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // 深色基底
            LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.12),
                                    Color(red: 0.02, green: 0.03, blue: 0.06)],
                           startPoint: .top, endPoint: .bottom)
            // 彩色光斑
            blob(LinearGradient(colors: [Color(red: 0.20, green: 0.55, blue: 1.0),
                                         Color(red: 0.35, green: 0.3, blue: 1.0)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: 340, height: 340)
                .offset(x: animate ? -120 : -160, y: animate ? -260 : -300)
            )

            blob(LinearGradient(colors: [Color(red: 0.2, green: 0.9, blue: 0.85),
                                         Color(red: 0.1, green: 0.5, blue: 0.9)],
                                startPoint: .top, endPoint: .bottom)
                .frame(width: 300, height: 300)
                .offset(x: animate ? 150 : 120, y: animate ? -180 : -140)
            )

            blob(LinearGradient(colors: [Color(red: 1.0, green: 0.35, blue: 0.7),
                                         Color(red: 0.7, green: 0.3, blue: 1.0)],
                                startPoint: .leading, endPoint: .trailing)
                .frame(width: 320, height: 320)
                .offset(x: animate ? 60 : 100, y: animate ? 320 : 280)
            )

            blob(LinearGradient(colors: [Color(red: 0.4, green: 0.8, blue: 1.0),
                                         Color(red: 0.3, green: 0.5, blue: 1.0)],
                                startPoint: .bottom, endPoint: .top)
                .frame(width: 260, height: 260)
                .offset(x: animate ? -160 : -120, y: animate ? 260 : 300)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .blur(radius: 90)
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
        .ignoresSafeArea()
    }

    private func blob(_ gradient: LinearGradient) -> some View {
        Circle().fill(gradient)
    }
}

#Preview {
    GlassBackground()
}
