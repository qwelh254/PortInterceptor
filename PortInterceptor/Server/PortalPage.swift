//
//  PortalPage.swift
//  门户验证页（内置 HTML）：通过本地代理访问验证网址时返回
//  对应你描述的「打开端口 → 网页显示验证端口成功」
//

import Foundation

enum PortalPage {
    /// 识别为「验证网址」的主机名（小写，不含端口）
    static let verificationHosts: Set<String> = [
        "captive.apple.com",
        "captive.portinterceptor.com",
        "portinterceptor.verify",
        "portinterceptor.local",
        "verify.local",
        "captive.network",
        "captive.connectivitycheck.local",
        "127.0.0.1",
        "localhost",
    ]

    static func isVerification(host: String) -> Bool {
        var h = host.lowercased()
        if let colon = h.range(of: ":") {
            h = String(h[h.startIndex..<colon.lowerBound])
        }
        if h == "captive.apple.com" { return true }
        return verificationHosts.contains(h)
    }

    static func html(configName: String,
                     nodes: Int,
                     rules: Int,
                     stats: ProxyStats.Snapshot,
                     port: UInt16) -> String {
        let now = ISO8601DateFormatter().string(from: Date())
        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <title>端口验证成功 · PortInterceptor</title>
        <style>
          * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
          body {
            margin: 0; min-height: 100vh;
            font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", sans-serif;
            background: radial-gradient(120% 120% at 50% 0%, #16202e 0%, #0a0d14 55%, #06080d 100%);
            color: #e8eef7; display: flex; align-items: center; justify-content: center;
            padding: 28px 18px;
          }
          .card {
            width: 100%; max-width: 460px;
            background: rgba(255,255,255,0.05);
            border: 1px solid rgba(255,255,255,0.09);
            border-radius: 24px; padding: 30px 24px;
            backdrop-filter: blur(18px);
            box-shadow: 0 24px 60px rgba(0,0,0,0.45);
          }
          .badge {
            width: 92px; height: 92px; margin: 4px auto 18px;
            border-radius: 50%;
            background: radial-gradient(circle at 35% 30%, #2bd97c, #12a257);
            display: flex; align-items: center; justify-content: center;
            box-shadow: 0 12px 30px rgba(29,185,116,0.4);
          }
          .badge svg { width: 48px; height: 48px; }
          h1 { font-size: 23px; text-align: center; margin: 0 0 6px; }
          .sub { text-align: center; color: #8fa3bd; font-size: 14px; margin-bottom: 22px; }
          .row {
            display: flex; justify-content: space-between; align-items: center;
            padding: 13px 14px; margin-bottom: 10px;
            background: rgba(255,255,255,0.04); border-radius: 14px; font-size: 14px;
          }
          .row .k { color: #93a6c0; }
          .row .v { font-weight: 600; font-variant-numeric: tabular-nums; }
          .mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
          .ok { color: #2bd97c; }
          .stats { display: flex; gap: 10px; margin: 18px 0 4px; }
          .stat {
            flex: 1; text-align: center; padding: 14px 6px;
            background: rgba(255,255,255,0.04); border-radius: 16px;
          }
          .stat .n { font-size: 22px; font-weight: 700; font-variant-numeric: tabular-nums; }
          .stat .l { font-size: 12px; color: #93a6c0; margin-top: 3px; }
          .tip {
            margin-top: 18px; font-size: 12.5px; color: #7d90ab; line-height: 1.7;
            text-align: center;
          }
          .foot { margin-top: 16px; text-align: center; font-size: 11px; color: #56657c; }
        </style>
        </head>
        <body>
          <div class="card">
            <div class="badge">
              <svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3"
                   stroke-linecap="round" stroke-linejoin="round">
                <polyline points="20 6 9 17 4 12"></polyline>
              </svg>
            </div>
            <h1>端口验证成功</h1>
            <div class="sub">本地代理端口已打开，拦截分流正在运行</div>

            <div class="row"><span class="k">代理地址</span>
              <span class="v mono">127.0.0.1:\(port)</span></div>
            <div class="row"><span class="k">当前配置</span><span class="v">\(configName)</span></div>
            <div class="row"><span class="k">节点 / 规则</span>
              <span class="v">\(nodes) 节点 · \(rules) 规则</span></div>
            <div class="row"><span class="k">运行状态</span><span class="v ok">● 已连接</span></div>

            <div class="stats">
              <div class="stat"><div class="n">\(stats.total)</div><div class="l">总请求</div></div>
              <div class="stat"><div class="n" style="color:#ff6b6b">\(stats.blocked)</div><div class="l">已拦截</div></div>
              <div class="stat"><div class="n" style="color:#2bd97c">\(stats.direct)</div><div class="l">直连</div></div>
            </div>

            <div class="tip">
              关闭本 App 的本地代理（或关闭 WiFi 手动代理）后，<br>
              再访问网页将直接打开原始网页（例如百度）。
            </div>
            <div class="foot">PortInterceptor · \(now)</div>
          </div>
        </body>
        </html>
        """
    }
}
