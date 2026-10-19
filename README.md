# PortInterceptor — iOS 端口拦截 / 规则分流客户端

一个类似 Surge / Clash 的 iOS 代理分流客户端：
**导入配置 → 自动识别格式 → 解析节点与规则 → 按规则直连 / 拦截 / 代理。**

本版提供**免费 Apple ID 就能真正拦截**的方案：App 内启动本地代理服务器
（`127.0.0.1:8888`），配合系统「WiFi → 手动 HTTP 代理」即可接管浏览器
HTTP/HTTPS 流量，并提供门户验证页与实时统计。

---

## 一、两种工作模式

### 模式 A：WiFi 手动代理 + 本地代理（免费账号可用，推荐）

- App 内本地代理服务器监听 `127.0.0.1:8888`；
- 在系统设置里把当前 WiFi 的 HTTP 代理设为手动，指向该地址；
- 之后浏览器的 HTTP/HTTPS 请求都会经过 App：
  - 命中 `REJECT` 的域名 → **拦截**（HTTPS 断开隧道，HTTP 返回拦截页）；
  - 命中 `DIRECT` 的域名 → **直连**；
  - 命名节点/策略组 → 有加密节点时走代理，无节点时回退直连（保证能上网）；
- 实时统计：总请求 / 已拦截 / 直连；
- **门户验证**：代理运行时访问验证网址，返回「端口验证成功」页面；关闭代理后
  再访问同一网址，则直接显示原始网页（如百度）。

> 局限：该模式作用于「遵守系统代理」的流量（Safari、多数 App 的 HTTP/HTTPS）；
> 不显示系统 VPN 图标，无法接管完全无视代理设置的连接。需要全局接管请用模式 B。

### 模式 B：Network Extension 全局 TUN（需付费开发者账号）

- 真正接管设备全部流量，状态栏显示 VPN 图标；
- 仅对 **99 美元/年的 Apple 付费开发者账号**开放，免费账号调用必失败，
  这是苹果的系统限制；
- 隧道内核代码已在 `PacketTunnel/` 完整写好，按第六节启用。

---

## 二、快速上手（模式 A）

1. 在「配置」页点右上角 ＋，从文件 / 剪贴板 / 订阅链接导入配置，App 自动识别；
2. 切到「连接」页，点 **启动代理**；
3. 按页面「WiFi 代理设置」五步，把当前 WiFi 的代理设为手动：
   `127.0.0.1`，端口 `8888`；
4. 点 **打开验证网页**：显示「端口验证成功」即说明拦截链路已通；
5. 用「拦截开关」在「直连模式（全部放行）」与「拦截模式（按 REJECT 拦截）」间切换。

---

## 三、没有 Mac，怎么拿到 IPA？（GitHub 云打包，免费）

IPA 必须在 macOS + Xcode 编译，但可用 GitHub 免费的云端 Mac 构建机。

1. 注册并登录 https://github.com；
2. 新建一个 **Private** 仓库；
3. 把本工程文件夹**里面的全部内容**（含 `project.yml`、`.github`、`PortInterceptor`、
   `PacketTunnel`、`Configs`）上传并 Commit；
   - 若网页上传看不到隐藏的 `.github`，用 **Add file → Create new file**，
     文件名填 `.github/workflows/build-ipa.yml`，内容粘贴本工程同名文件；
4. 打开 **Actions** 标签，首次点 **I understand my workflows, enable them**；
   「Build IPA」会自动运行（约 8–15 分钟）；
5. 构建变绿后，在页面底部 **Artifacts** 下载
   `PortInterceptor-unsigned-ipa`，解压得到 `PortInterceptor-unsigned.ipa`。

> 之后想重新打包，Actions → Build IPA → Run workflow 即可。

---

## 四、把 IPA 安装到 iPhone（免费 Apple ID 签名）

未签名 IPA 需用 Apple ID 免费重签，工具任选：

- **Sideloadly**（推荐）：https://sideloadly.io
  把 IPA 拖入 → 填 Apple ID → Start；iPhone 上
  「设置 → 通用 → VPN与设备管理」里信任该 Apple ID。
- **AltStore**（可自动续期）：https://altstore.io

免费签名固定限制（苹果规定）：7 天过期需重签；最多同时装 3 个自签 App。
（模式 A 不依赖任何特殊 entitlement，免费签名下功能完整。）

---

## 五、代码结构

```
PortInterceptor/
├── .github/workflows/build-ipa.yml   # GitHub 云端自动打包 IPA
├── buildIPA.sh                       # Mac 本地一键打 IPA
├── project.yml                       # XcodeGen 工程定义
├── Configs/                          # 三种格式示例配置
├── PortInterceptor/                  # 主 App
│   ├── Models/                       # 节点 / 策略组 / 规则 / 配置
│   ├── Parsing/
│   │   ├── ConfigFormatDetector.swift  # 自动识别（含 Base64 嗅探）
│   │   ├── ClashConfigParser.swift     # Clash YAML
│   │   ├── SurgeConfigParser.swift     # Surge/Loon/QX
│   │   ├── NodeURIParser.swift         # ss:// vmess:// 等
│   │   ├── SubscriptionParser.swift    # 订阅解析
│   │   └── ConfigImporter.swift        # 统一入口
│   ├── Rules/RuleEngine.swift       # 规则匹配引擎（异步）
│   ├── Server/                      # App 内本地代理（模式 A 核心）
│   │   ├── LocalProxyServer.swift    # 本地 HTTP 代理（CONNECT 分流）
│   │   ├── LocalRuleMatcher.swift    # 同步规则匹配
│   │   ├── ProxyServerManager.swift  # 启停 / 状态 / 拦截开关
│   │   ├── ProxyStats.swift          # 线程安全统计
│   │   └── PortalPage.swift          # 门户验证页（内置 HTML）
│   ├── Tunnel/TunnelManager.swift   # VPN 开关（模式 B，付费账号）
│   └── Views/                       # SwiftUI 深色三页
└── PacketTunnel/                    # 网络扩展（模式 B，付费账号后启用）
    ├── PacketTunnelProvider.swift
    ├── LocalHTTPProxy.swift
    └── SharedRuleMatcher.swift
```

---

## 六、付费账号后如何开启全局隧道（模式 B）

1. Xcode `File → New → Target…` 选 `Network Extension`，模板
   `Packet Tunnel Provider`，Product Name 填 `PacketTunnel`；
2. 扩展 Bundle ID 与 `TunnelManager.swift` 中 `extensionBundleID` 一致；
3. 删除模板自带文件，把 `PacketTunnel/` 三个文件拖入，**只勾选扩展 target**；
4. 主 App 与扩展均 `+ Capability`：`Network Extensions (Packet Tunnel)`、
   `App Groups`（填同一个 group）；
5. 重新运行即可在「连接」页启动全局隧道。

---

## 七、合规提醒

- 本项目仅用于学习 iOS 网络技术、调试自有 App 的网络请求与合法的隐私保护；
- 网络代理工具的使用须遵守所在地法律法规；
- 此类 App 上架有额外审核要求（中国大陆还需相关资质），请勿直接用于上架发布。
