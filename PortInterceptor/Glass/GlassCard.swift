//
//  GlassCard.swift
//  液态玻璃卡片：ultraThinMaterial 磨砂 + 顶部高光 + 渐变描边 + 柔和阴影
//

import SwiftUI

extension View {
    /// 液态玻璃容器
    func glassCard(cornerRadius: CGFloat = 26,
                   tint: Color = .white) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint))
    }
}

struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            }
            .background {
                // 顶部高光，营造玻璃质感
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.22),
                                                 tint.opacity(0.04),
                                                 tint.opacity(0.0)],
                                         startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.35),
                                               .white.opacity(0.12),
                                               .white.opacity(0.03)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
    }
}

// MARK: - 玻璃圆形按钮
struct GlassCircleButton: View {
    let systemImage: String
    let size: CGFloat
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                Circle().fill(LinearGradient(colors: [.white.opacity(0.25),
                                                      .white.opacity(0.02)],
                                             startPoint: .top, endPoint: .bottom))
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(GlassTheme.accent)
            }
            .frame(width: size, height: size)
            .overlay {
                Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        }
    }
}

// MARK: - 玻璃圆形图标（纯视图，可作为 Menu 的 label）
struct GlassCircleIcon: View {
    let systemImage: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial)
            Circle().fill(LinearGradient(colors: [.white.opacity(0.25),
                                                 .white.opacity(0.02)],
                                        startPoint: .top, endPoint: .bottom))
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(GlassTheme.accent)
        }
        .frame(width: size, height: size)
        .overlay { Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1) }
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
    }
}

// MARK: - 主题
enum GlassTheme {
    static let accent = Color(red: 0.45, green: 0.92, blue: 1.0)
    static let green = Color(red: 0.2, green: 0.95, blue: 0.55)
    static let red = Color(red: 1.0, green: 0.42, blue: 0.46)
    static let purple = Color(red: 0.7, green: 0.55, blue: 1.0)
}
