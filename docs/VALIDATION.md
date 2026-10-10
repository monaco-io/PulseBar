# 本机验证记录

## 2026-10-10：v1.13.1 发布前验证

- 本次发布包含上下双行速率、固定数值列和磁盘 / 网络分组悬停详情；版本 1.13.1（22），已补齐英文与简体中文发行说明。
- 冻结源码快照的 102 项测试通过；版本与构建递增、Info.plist 和中英文本地化资源语法、差异空白检查通过。沿用下方同一菜单栏绘制代码的 780 组几何检查，以及分组悬停的隔离验证记录。
- 本机发布前证据在 `.build/release-v1.13.1/`。公开 DMG、更新源和正式安装结果以发布后验证为准；实际桌面截图与物理指针悬停未补验，不将离屏绘制或采样检查作为其通过证据。

## 2026-10-10：上下双行读数（本机已替换，未发布）

- 磁盘上行为 R 读取、下行为 W 写入；网络上行为 ↓ 下载、下行为 ↑ 上传。使用 10.5 pt 等宽数字，每组右侧居中共用一个 8.5 pt MB/s，不显示横条。标签、36 pt 右对齐数字列和单位分别固定位置；每组 79 pt，四项全部开启时图片为 208 × 22 pt，包含系统留白的状态项为 220 pt。长数字在自身列内缩小，保留现有分组悬停详情和 CPU / 内存双环。
- 复用原生绘制与几何检查，15 种非空显示组合 × 4 个数值位置 × 13 种读数共 780 组全部保持图片尺寸及悬停范围不变。检查空闲、微小值、正常值、长数字及缺失值的真实离屏绘制，无跨列重叠。相对上一安装版仅 `MenuBarLabel.swift` 一项构建输入变化，其余 80 项一致，未重复未改动的核心测试。证据位于 `.build/stacked-rate-values/`。
- arm64 / x86_64 Release、通用架构和深度严格签名检查通过。已替换 `/Applications/PulseBar.app` 并启动，版本仍为 1.13.0（21），核验 PID 65385。二进制 SHA-256 `2a9e6b1440bf0631c5847e49750ecb5526958d7fb4d199ecf8f36e487166f34a` 与构建和 dist 一致；偏好及原有 144 条事件保留，安装后 3 次只读采样通过。
- 备份位于 `/Users/xuzelu/Library/Application Support/PulseBar/Backups/2026-10-10-143911-stacked-rate-values`。原生界面读取超时，未取得实际桌面菜单栏截图，不将离屏绘制检查视为实机指针悬停验收。未提交、推送或发布。

## 2026-10-10：固定菜单栏指标宽度（本机已替换，未发布）

- 修复刷新时按当前字符串测量组宽导致的横向抖动。磁盘、网络各固定为 132 pt，两项数值各占 36 pt 并右对齐；图标、斜线、单位、分组分隔线和悬停锚点的位置保持不变。四项全部开启时图片固定为 314 × 22 pt，状态项连同系统左右留白为 326 pt；只切换可见指标时才改变占用宽度。超出数值列的长读数在列内缩小，悬停详情继续显示完整正常字号读数。
- 对生产绘制代码做前后回归检查：15 种非空指标组合 × 4 个数值位置 × 13 种读数，共 780 组。修复前有 352 组改变了图片尺寸或悬停范围，修复后 780 组全部稳定；正常值、微小值、大值和缺失值的原生离屏图经检查，无跨列重叠或单位位移。证据在 `.build/fixed-rate-width/` 的前后 JSON、PNG 和构建记录。本次仅修改绘制文件，不重复运行未变的核心测试。
- 相对上一安装版只有 `MenuBarLabel.swift` 一项构建输入变化，其余 80 项保持一致。arm64 / x86_64 Release、通用架构、深度严格签名检查通过；已替换 `/Applications/PulseBar.app` 并启动，版本 1.13.0（21），运行 PID 54738。二进制 SHA-256 `ebd0ef34570686bb59a29f6687deab8e1d644bc0d5c8838c1f54ff0aa4de0113` 与本次产物和 dist 一致；设置与原有 143 条事件保留，安装后 3 次只读采样无错误。
- 备份位于 `/Users/xuzelu/Library/Application Support/PulseBar/Backups/2026-10-10-140830-fixed-rate-width`。原生界面读取超时，未获得实际桌面菜单栏截图，不把绘制回归检查称为物理桌面视觉验收。未提交、推送或发布。

## 2026-10-10：方案 4 单行速率与分组悬停（本机已替换，未发布）

- 菜单栏磁盘和网络采用原生 SF Symbols、11.5 pt 单行数值、弱化的斜线和 8.5 pt 共用单位；从左到右为读取 / 写入、下载 / 上传，每组仅一个 MB/s。绘制与悬停范围共用同一份测量布局，大数值按内容扩展；CPU / 内存双环和完整辅助功能速率描述保留。
- 磁盘、网络和双环共用一个被动原生玻璃提示窗。停留 0.2 秒显示对应内容，磁盘和网络含两项实时速率及本次累计量；移出、点击、打开原生菜单、隐藏指标或切换屏幕时取消。跟踪区域在采样时保持身份，旧区域迟到的退出和旧延迟任务不能关掉或重开新区域的提示。
- 102 项现有测试通过；隔离 AppKit 检查 37 项通过，覆盖延迟取消、跨组切换、被动焦点、窗口屏幕边界、持续实时采样、跟踪区域稳定、显示项切换及正常 / 大值 / 缺失值的真实绘制。已检查中英文内容与布局，原生辅助功能读取确认网络面板的下载、上传和累计量。玻璃离屏截图中深色文字对比度异常，但桌面截图工具持续超时，未能区分材质捕获问题与实机表现，深色效果未完成视觉确认。实际桌面菜单栏截图与物理指针悬停仍待现场核对。
- 81 项构建输入与冻结快照一致；arm64 / x86_64 Release、通用架构、深度严格签名以及安装后 3 次无错误只读采样通过。已更新 `/Applications/PulseBar.app`，版本仍为 1.13.0（21），运行 PID 53409；二进制 SHA-256 `edb3351d34e699f994929446f2ba311406f09cdb3ecee286b73b59b1596fbf5f` 与本次产物和 dist 一致。原有设置及 142 条事件逐条保留，启动后 143 条；两份本地化资源与源码一致。
- 备份位于 `~/Library/Application Support/PulseBar/Backups/2026-10-10-140445-minimal-rate-hover/`，源码、检查、构建和安装证据在 `.build/minimal-rate-hover/`。未提交、推送或发布。

## 2026-10-10：v1.13.0 正式发布与安装验证

- [PulseBar 1.13.0](https://github.com/monaco-io/PulseBar/releases/tag/v1.13.0) 已发布为 Latest，构建号 21，标签源码为 `6d66ed70c98afb32b19c0086381869f399d22142`。[CI](https://github.com/monaco-io/PulseBar/actions/runs/38021523988) 与[正式发布流程](https://github.com/monaco-io/PulseBar/actions/runs/38021700736) 均成功，覆盖 102 项测试、arm64 / x86_64 构建及打包应用采样。
- 唯一上传附件为 `PulseBar.dmg`（3,011,818 字节）；匿名下载返回 HTTP 200，SHA-256 `6bdac3574153942e47904d77e01eedc3bf54c00500473ceadf2b3ebd4d6480a5` 与 GitHub 资产摘要一致。仅用应用内公钥独立验证 DMG 与 appcast 的 Ed25519 签名；固定公开更新源已返回 1.13.0（21），与更新分支内容逐字节一致。
- 挂载 DMG 核验仅有应用和 Applications 链接两项可见内容，Finder 布局模板、资源、Sparkle 框架、版本、系统要求、双架构和深度严格签名检查通过。发行说明与仓库英文源文件一致。证据为 `artifacts/github-v1.13.0/`。
- 已将公开 DMG 中的原样应用安装至 `/Applications/PulseBar.app` 并启动，单个 GUI 进程 PID 16455。安装后二进制 SHA-256 为 `485517701744c070edff2f5f4c0a1e9c94713ffa28cf013d66c0a32c7c7ee3b8`，与正式 DMG 一致；原有偏好与 140 条事件全部保留，3 次只读采样退出成功且无错误。旧应用和数据备份在 `~/Library/Application Support/PulseBar/Backups/2026-10-10-114853-release-1.13.0/`，安装证据见 `.build/release-v1.13.0/`。
- 正式安装后的原生界面读取超时，未补验应用内更新弹窗或包含桌面阴影的截图；Intel 实机和旧 macOS 界面仍未验收。公开包与更新源校验不代替这些界面验证。发布继续使用临时签名，未经过 Apple 公证。

## 2026-10-10：v1.13.0 发布前验证

- 本次发布汇总当前紧凑原生玻璃界面、独立详情窗、菜单栏双环与交互、辅助进程归属，以及共用速率单位、外层圆角和首次详情高度修复；版本为 1.13.0（21），英文和简体中文发行说明已补齐。
- 对冻结的非同步源码快照运行现有完整测试，102 项通过；版本 / 构建递增检查、中英文资源与 Info.plist 语法检查、差异空白检查通过。构建输入与工作区逐项核对，详情首次布局的真实窗口回归证据见下方记录。
- GitHub CI、正式 DMG、更新源和安装版仍以本次发布后的验证结果为准。此前尚未完成的桌面阴影视觉复核、Intel 实机与旧版 macOS 界面验证不因测试通过而视为完成。
- 本机发布前证据保存在 `.build/release-v1.13.0/`；以下未发布记录描述各次本地改动时的状态。

## 2026-10-10：首次展开详情窗顶部裁切（已复现、修复并替换本机）

- 根因是详情首次布局已测得新高度，但 `resizeToFitContent` 以窗口尚不可见为由提前返回，造成 SwiftUI 内容高度与真实窗口高度不同；根层圆角裁切会截去溢出的顶部。现允许隐藏窗口接收尺寸更新，并在首次显示前重新应用测量结果；首次调整不播放缩放动画，后续可见窗口保留系统动画与屏幕边界约束。
- 使用隔离配置、事件目录和真实监控视图在全新进程中复现首次悬停展开：修复前内容需要 854 pt，窗口仍为 600 pt，标题、历史控制和顶部数据被裁切，截图与用户现象一致；修复后首次展开两者均为 854 pt，标题和全部顶部内容完整。随后模拟隐藏期间内容高度变为 781 pt，修复前窗口仍为 600 pt，修复后同步为 781 pt。两项回归均呈现修复前失败、修复后通过；自动检查只驱动本次隔离预览，不操作生产配置或事件。
- 相对上一安装版仅有 `DetailWindowCoordinator.swift` 一项构建输入变化。移除临时预览检查代码并核对 80 项生产构建输入后，arm64 / x86_64 Release、通用架构及深度严格签名检查通过。`/Applications/PulseBar.app` 已更新并运行，版本仍为 1.12.0（20），二进制 SHA-256 为 `4da9e48d8c9992db434c34d2f887cfa58bb8df62e86f36a64eb9a3abd8cdce79`，与本次产物及 `dist` 一致；偏好和原有 138 条事件保留。
- 证据见 `.build/first-detail-layout/` 的前后回归 JSON、首次展开 PNG、原生窗口日志、构建和安装记录；备份位于 `~/Library/Application Support/PulseBar/Backups/2026-10-10-113123-first-detail-layout/`。未提交、推送或发布。

## 2026-10-10：玻璃浮窗外层圆角与阴影轮廓（本机已替换，桌面阴影待复核）

- 用户截图显示底部玻璃圆角外仍有矩形边缘。原实现仅设置内层玻璃圆角；本次在共享 `NativeGlassContainer` 根层增加同半径的连续圆角裁切，并在布局尺寸变化时调用 `NSWindow.invalidateShadow()`，让窗口重新计算阴影。总览、详情及悬停提示共用此修正，保留系统玻璃和窗口阴影。
- 相对上一安装版仅有 `NativeGlassHosting.swift` 一项构建输入变化。arm64 / x86_64 Release、通用架构及深度严格签名检查通过；未新增布局实现镜像测试。`/Applications/PulseBar.app` 已更新并运行，版本仍为 1.12.0（20），二进制 SHA-256 为 `c502f2f1a3b685db27f6f5d66d1d2ced79f68a3145afd9f00615803d081070e5`，与本次产物和 `dist` 一致。配置及原有 137 条事件保留。
- 备份位于 `~/Library/Application Support/PulseBar/Backups/2026-10-10-111440-rounded-window-outline/`，证据见 `.build/rounded-window-outline/`。安装后原生 UI 读取超时，尚未取得包含桌面阴影的新截图，不能据此宣称用户标出的直角已完成视觉验收。未提交、推送或发布。

## 2026-10-10：菜单栏磁盘和网络共用速率单位（本机已替换，未发布）

- 磁盘读 / 写和网络下载 / 上传各在右侧居中显示一个 `MB/s`，上下数值共用单位，合计由四个减为两个。保留既有字号、组宽、分隔线、圆环及辅助功能中的完整速率描述；大数值仍按内容扩展宽度。
- 相对上一安装版仅有 `MenuBarLabel.swift` 与 `AppDelegate.swift` 两项构建输入变化。arm64 / x86_64 Release 构建、通用架构及深度严格签名检查通过。真实绘制代码离屏渲染检查覆盖正常值、大数值与微小值、不可用状态，以及单独显示磁盘或网络；未新增布局实现镜像测试。
- `/Applications/PulseBar.app` 已替换并运行，版本 1.12.0（20），核验 PID 823。二进制 SHA-256 为 `cfdb5115ec9acc0d85344e622bfc8804767a77c073831d7f578f0ac4d2e4f7fa`，与本次构建及 `dist` 一致。偏好与原有 135 条事件保留；备份位于 `~/Library/Application Support/PulseBar/Backups/2026-10-10-110819-shared-rate-units/`。证据见 `.build/shared-rate-units/`。原生界面工具读取菜单栏超时，视觉检查为真实绘制代码的离屏预览，不是实机菜单栏截图。未提交、推送或发布。

## 2026-10-10：外圈内存与三色压力显示（本机已替换，未发布）

- 双环改为外圈内存、内圈 CPU，中英文悬停行及辅助功能说明同步。保留直径 22 / 12 pt、等粗 3 pt、2 pt 边缘间距和完整系统灰色底轨。亮弧仍表示占用比例；内存颜色读取现有 `kern.memorystatus_vm_pressure_level`，正常 / 偏高 / 紧张分别使用 `NSColor.systemGreen` / `systemYellow` / `systemRed`，压力或用量不可用时为灰色，与 [Apple 内存压力说明](https://support.apple.com/guide/activity-monitor/check-if-your-mac-needs-more-ram-actmntr34865/mac) 的三色含义一致。CPU 采用 PulseBar 的占用率显示分档：低于 60% 绿、60–80% 黄、超过 80% 红，不将此分档称为系统内存压力算法。
- 内存详情等既有压力指示统一改用系统三色，悬停浮窗增加一行内存压力文字，按可见指标扩展高度；百分比继续三列对齐。圆环数值和颜色使用 SwiftUI 过渡并遵循减少动态效果。菜单栏点击行为、采样、设置和事件逻辑未改。
- 80 项构建输入与非同步构建快照一致；arm64 / x86_64 Release 编译、通用架构及深度严格签名验证通过，安装包两份本地化资源与源码逐字节相同。只读诊断连续两次采样无错误：内存约 82%，压力均为 1（正常）；有效 CPU 样本为 66.5%，对应新的黄色区间。首个 CPU 样本为建立基线而缺省。本次未新增或重复运行布局 / 配色实现镜像测试。
- `/Applications/PulseBar.app` 已替换并启动，版本 1.12.0（20），PID 61205，二进制 SHA-256 为 `cbe5ce7b6e6e3c06d8789e4c8ab0b151c48d14b88920ec39d2f0e61decba3d81`，与构建产物一致。偏好及原有 131 条事件完整保留。旧 app、偏好和事件备份在 `~/Library/Application Support/PulseBar/Backups/2026-10-10-100246-memory-pressure-rings/`。证据为 `.build/memory-pressure-rings-build.log` 和 `.build/memory-pressure-rings-install/`。原生界面读取超时，未取得菜单栏实机截图，不将采样验证视为三色视觉验收。没有提交、推送或发布。

## 2026-10-10：清晰底轨双环（本机已替换，未发布）

- 用户选择已展示的“清晰底轨”方案。两圈继续通过 SwiftUI `Gauge` / 公开 `GaugeStyle` 绘制，均为 3 pt；外圈 CPU 直径 22 pt，内圈内存直径 12 pt，边缘间距由 1.5 pt 增为 2 pt。完整底轨改为系统灰色、45% 不透明度，与绿色 / 超过 80% 的红色进度独立；两圈不做位置补偿，原有悬停、点击和减少动态效果逻辑保留。
- 使用当前工作区的非同步源码快照构建，保留当前安装版已经包含的进程归属改进。80 项代码、测试、脚本和资源输入在构建前后核对一致。arm64 / x86_64 Release 编译、通用架构及深度严格签名校验通过。首次打包发现复制缓存与 SwiftPM 新身份各有一份 Sparkle，移除本次临时目录内未使用的旧身份缓存后重新打包成功。此改动只涉及尺寸和样式，没有新增或重复运行实现镜像测试。
- `/Applications/PulseBar.app` 已替换并启动，版本 1.12.0（20），实际运行 PID 54728；二进制 SHA-256 为 `997fac3daea6e6bf1c3527e989a24dec2df0feda2a2727560b950de017baaa89`，与构建产物一致。原生界面读取超时，尚未取得实际菜单栏圆环截图，不能据此宣称视觉偏移已经通过实机验收。
- 实际偏好保持一致，原有 128 条事件逐条保留，启动后为 129 条。旧 app、偏好及事件备份在 `~/Library/Application Support/PulseBar/Backups/2026-10-10-094936-clear-ring-track/`。证据为 `.build/clear-ring-track-build.log` 与 `.build/clear-ring-track-install/`。没有提交、推送或发布。

## 2026-10-10：悬停读数三列对齐（本机已替换，未发布）

- 用户确认悬停读数和重复展开“两项都正常”后，要求对齐提示内容。悬停提示改用原生 SwiftUI `Grid`：圈层说明、指标名称、百分比分列；数字使用等宽字形和统一 52 pt 右对齐列，保留 240 pt 浮窗宽度与按可见指标数量确定的高度。英文和简体中文分别提供独立圈层标签；两环仍均为 3 pt。
- 本次只改动提示视图、本地化键和两个语言文件。两份资源语法检查、arm64 / x86_64 Release 构建、通用架构及深度严格签名检查通过。前一轮 99 项测试覆盖未改动的交互状态；本次未新增或重复运行布局实现镜像测试。
- `/Applications/PulseBar.app` 已替换并运行，PID 49822，版本 1.12.0（20）；二进制 SHA-256 为 `d9675c70a25ab8327a96bdf53af07121e8fc9c14da91eff239a48cdbbde0120f`，与此次构建一致。实际安装包包含两种语言的新圈层标签，原生 AX 读取确认总览正常采样；三列布局的实际悬停截图尚未取得。
- 实际偏好未改变，原有 126 条事件逐条保留，验证时为 127 条。备份位于 `~/Library/Application Support/PulseBar/Backups/2026-10-10-093534-status-hint-alignment/`。证据为 `.build/status-hint-alignment-build.log`、`.build/status-hint-alignment-install/`。
- 构建使用临时源码快照，与前一版输入相比仅包含上述 4 个文件变化；并行的 `ProcessMetrics.swift` 及其测试修改留在工作区，未纳入这次 UI 安装。没有提交、推送或发布。

## 2026-10-10：菜单栏悬停、重复展开与等粗双环（本机已替换，未发布）

- 双环继续使用 SwiftUI `Gauge`，通过公开 `GaugeStyle` 接口设置菜单栏尺寸下的线宽。最终外圈 CPU / 内圈内存均为 **3 pt**，直径分别为 22 / 13 pt，默认绿色、各自超过 80% 时变红；保留系统 SwiftUI 动画并遵循减少动态效果。
- 悬停由原生 `NSTrackingArea.activeAlways` 处理，停留 200 ms 后显示被动 `NSPanel`，内容由真实 `NSGlassEffectView` 承载，标明内外圈含义并实时更新百分比。面板不接收鼠标事件，移开或点击即关闭；采样不再反复重设数值 tooltip。
- 菜单栏使用原生按钮的 mouse-down 动作；展开意图与窗口动画状态分离。每次展开使用独立事件代次，关闭先移除监听，外部点击排除状态按钮区域与原生菜单；重新展开时激活应用并处理当前桌面。
- 99 项测试通过，新增回归覆盖延迟关闭事件、状态按钮 / 原生菜单排除及 20 次状态开关循环。这些是状态逻辑测试，不能视为真实菜单栏点击验收。最终等粗样式通过 arm64 / x86_64 Release 编译、通用架构检查和深度严格签名检查；初次工作区构建遇到缓存输入被同步修改，最终改用非同步临时构建目录。
- 已正常退出旧版并更新 `/Applications/PulseBar.app`，版本仍为 1.12.0（20），运行 PID 47675。最终二进制 SHA-256 为 `1db1a56545d5b5cdce254fdb0f9abf8d60437719eab7563ea1e1209229eb7fbd`。原生 AX 读取确认安装版总览显示真实采样；用户实际核对菜单栏悬停和连续开关后回复“两项都正常”，并提供了实时 CPU / 内存提示截图。实际指针交互的验收来自用户确认，不将总览 AX 读取视为该项证据；用户随后要求提示文字和数值对齐。
- 偏好保留系统语言、2 秒刷新、60 秒范围、四项菜单栏指标和通知开启；原有 125 条事件逐条保留，验证时为 126 条。备份位于 `~/Library/Application Support/PulseBar/Backups/2026-10-10-093102-status-interaction/`；证据为 `.build/status-interaction-tests.log`、`.build/status-interaction-build.log`、`.build/status-interaction-install/`。
- 安装前核对 56 项源代码和资源输入一致。安装后发现另有 `ProcessMetrics.swift` 进程归属修改，已保留且未混入这次安装；上述测试和二进制证据对应记录的构建输入，不代表之后的全部工作区修改。没有提交、推送或发布。

## 2026-10-09：菜单栏绿色同心双环（本机已替换，未发布）

- CPU / 内存数字改为原生 SwiftUI `Gauge.accessoryCircularCapacity` 同心双环，外圈 CPU、内圈内存，默认系统绿色；各自实际占用超过 80% 时变红，减少动态效果设置关闭过渡。原生仪表按实测固有尺寸缩入 22 pt 菜单栏位置。磁盘、网速继续用系统模板图像显示，保留原生按钮点击和高亮。
- 系统原生悬停提示及辅助功能值包含“外圈 · CPU”和“内圈 · 内存”的准确百分比，提示同时解释亮弧和 80% 规则；中英文资源完整，隐藏单个指标时保留其余指标原有环位置。
- 96 项现有测试通过；最终 arm64 / x86_64 通用构建通过。工作区同步产生的 Finder 扩展属性曾使工作区产物独立签名验证失败；复制至非同步目录并去除扩展属性后，暂存包和实际安装包均通过深度严格签名验证。
- 已正常退出旧进程并更新 `/Applications/PulseBar.app`，版本仍为 1.12.0（20）。最终二进制 SHA-256 为 `d69b0db6c53f39ab5044607a54af22fa436d3357c04851655ea84b06daaa55a7`，安装包与构建产物一致，实际运行 PID 88197。原生辅助功能读取确认最终安装版总览正常展开并持续显示真实采样；本轮界面工具没有覆盖菜单栏的实际指针悬停或圆环截图，不能将总览读取当作这两项验证。
- 保留替换前的实际偏好：跟随系统、2 秒刷新、60 秒范围、四项菜单栏指标和通知开启；原有 120 条事件逐条保留。备份位于 `~/Library/Application Support/PulseBar/Backups/2026-10-09-203430-stamina-rings/`。测试、构建和安装记录分别为 `.build/stamina-rings-tests.log`、`.build/stamina-rings-build.log`、`.build/stamina-rings-install/`。未提交、推送或发布。

## 2026-10-09：官方控件与内容自适应高度（本机已替换，未发布）

- 根据用户要求，移除自绘按钮外壳、手动悬停着色、缩放和 Core Animation；动作按钮与菜单改为真正的 AppKit `NSButton` / `NSPopUpButton`，macOS 26+ 使用公开 glass bezel。设置统一为原生 `GroupBox`、`LabeledContent`、输入框、开关、选择器和 `NSStepper`；事件使用 `DisclosureGroup`，曲线使用 Swift Charts。面板继续由实际 `NSGlassEffectView.contentView` 承载，透明度和对比度交给系统材质处理。
- 所有浮窗按标题、历史选项和正文的实测内容高度伸缩，上限为当前屏幕可用高度的 80%；超过上限才滚动。单一内容树保留事件展开与输入状态；重新打开保留测得高度，固定详情跨屏后重新限制高度。出现、消失与尺寸变化使用 AppKit 系统动画，减少动态效果时关闭尺寸动画。
- 96 项测试通过，包括内容增长、收起、短屏和 80% 上限取整；最新 arm64 / x86_64 Release 构建、通用架构及独立严格签名检查通过。60 项构建输入在构建前后保持一致。macOS 13 和 Intel 的实际界面未在本机验收。
- 原生预览中实际确认硬件悬停打开独立详情；事件原生展开 / 收起使窗口从约 250 pt 增长到 892 pt，再缩回 250 pt。当前可用屏幕高度为 1230 pt，其 80% 为 984 pt，因此该次展开验证的是内容自适应，不能作为达到上限的 GUI 证据；上限由单元测试覆盖。当前预览日志记录真实 `NSGlassEffectView` 以及原生 glass bezel 值 16。
- 设置页早期 `Form` 候选出现标签重复和列宽失衡，已改为一致的 `GroupBox` 行布局和完整宽度输入框。用户对最终预览回复“已关闭，布局正常”。安装后总览的原生辅助功能读取成功，设置入口点击已发出；随后自动界面工具反复报 native pipe / ScreenCaptureKit 错误，未取得最终安装版设置截图，不将用户的预览确认称为安装版截图验收。
- 已正常退出旧进程并替换 `/Applications/PulseBar.app`，版本仍为 1.12.0（20）。最终二进制 SHA-256：`1d920365a187890efee760530338b136a5ff214b8f4276c0ce8cd992a4ad82cb`，与本次通用构建一致，实际运行 PID 70414 来自该路径。偏好保留跟随系统语言、2 秒刷新、12 小时范围、四项菜单栏指标及通知开关；原有 116 条事件逐条保留。`~/Applications/PulseBar.app` 旧副本未变。
- 旧 app、偏好与事件备份：`~/Library/Application Support/PulseBar/Backups/2026-10-09-200033/`。证据：`.build/official-ui-install/`、`.build/official-ui-install-build.log`、`.build/official-ui-tests.log` 和会话中的原生 UI 结果；没有提交、推送或发布。

## 2026-10-09：用户授权替换本机安装版

- 用户要求“替换一下我看看”后，运行标准 `scripts/build-app.sh`，arm64 与 x86_64 Release 构建、通用二进制检查、深度严格签名检查均通过；构建前后 53 项源代码与资源输入一致。
- 正常退出旧进程后，将 `/Applications/PulseBar.app` 替换为当前紧凑总览候选，版本仍为 1.12.0（20）。安装后二进制与本次产物 SHA-256 一致：`b753cb3414425127d27f30b14f43cf7bbe6bbcca9d0cbe985059b77fae614b6b`。新进程实际从 `/Applications/PulseBar.app/Contents/MacOS/PulseBar` 运行，严格签名再次通过。
- 原生 UI 读取确认实际安装版显示新总览、独立详情入口、齿轮和更多菜单，底部四项导航已消失；保留跟随系统语言、2 秒刷新、12 小时自定义范围和四项菜单栏指标。旧的 112 条事件内容逐条保留，新进程正常新增了 1 条事件；不以运行中事件文件逐字节不变作为数据保留条件。
- 旧 app、偏好及事件文件备份在 `~/Library/Application Support/PulseBar/Backups/2026-10-09-193352/`。`~/Applications/PulseBar.app` 旧副本未变。替换证据位于 `.build/compact-ui-install/`，构建日志为 `.build/compact-ui-install-build.log`；没有提交、推送或发布。

## 2026-10-09：紧凑原生玻璃总览与独立详情窗（本地预览，未发布）

- 主总览改为 452 × 600 pt，短屏幕按可用高度收缩；移除底部四项导航和返回总览按钮。硬件模块负责打开独立详情窗，CPU / 内存详情包含应用排行，齿轮打开设置，“更多”打开事件及其他操作。
- macOS 27.0（26A428）、Apple Silicon、Swift 6.0.3 / macOS 15.2 SDK 下，94 项测试通过，Debug 和本机 Release 构建通过。新增几何测试覆盖独立详情的右侧、左侧回退与屏幕边界约束；本次没有构建 Intel 产物。
- 通过当前会话的原生 UI 工具实际检查总览、CPU / 网络详情、设置和事件。总览固定在 452 × 600 pt，没有底栏及多余滚动条；点击后详情使用独立窗口，主窗口位置、尺寸保持不变。关闭按钮和 Escape 能关闭详情并返回原总览。CPU 长详情可以滚动到底部应用排行与活动监视器入口。
- 设置的中英文布局均完整可见，语言已恢复为简体中文。事件在展开后保留采样与应用快照，实际滚动到底部仍保持展开；用单一内容树和原生自动隐藏滚动条避免静态 / 滚动容器切换导致展开状态重置。
- 预览日志确认主材质为实际 `NSGlassEffectView`。按钮保留 AppKit 行为并增加悬停着色、按压和释放反馈；独立详情入口使用原生 `NSTrackingArea.activeAlways`，适配应用未激活的菜单栏面板。真实指针悬停自动弹窗及跨窗口移动仍待用户核对，未将点击验证算作悬停验收；固定后拖动、关闭生产总览后保留详情也未完成本轮 UI 验收。
- 运行的是 `/tmp/pulsebar-native-preview-sign.app` 内的隔离 DEBUG 预览，使用真实系统采样、独立偏好和临时事件数据。临时目录中的预览通过严格签名检查；同步目录会重新附加 Finder 元数据，因此不将工作区 app 副本视为签名验收产物。
- 日志位于 `.build/compact-ui-tests.log`、`.build/compact-ui-release.log`、`.build/native-glass-preview.log`。没有安装、替换已安装应用、提交、推送或发布。旧 macOS 材质回退、减少透明度、实体电池及多 GPU 均未纳入本轮 UI 验收。

## 2026-10-08：v1.12.0 排版实现与发布前验收

- 按审核设计落实 CPU / 内存、存储 / 网络及可用 GPU / 内置电池布局，主百分比 28 pt、双向速率 24 pt，标签与数值使用固定列；保留所有原有可用指标、四组纯线历史与联动查看。总览宽 620 pt、高度最多 660 pt，宽度不足 500 pt 单列，中部滚动；详情侧栏展开为 941 pt。新增锚点测试覆盖总览右边与状态项右边对齐。
- 92 项测试通过；arm64+x86_64 release 构建和独立 deep strict 签名检查通过。最终 69 项构建输入与独立构建副本逐字节一致；最后仅修改 DEBUG 预览坐标和尺寸夹具后增量重建，release 二进制 SHA-256 保持 `f7f6de26eb99fafbdff88c3f674bcc9d7cabc48027a16af33a2df32fc5f7e7d2`。核心与测试树未变，沿用完整 92 项测试及同一二进制的三次真实采样证据。
- 三次真实采样无错误，本机 M4 CPU / GPU / 存储温度、逐设备 GPU 利用率和启动数据卷容量有效；无有效内存温度，无内置电池，缺失项隐藏。采集、配置和事件业务逻辑未改；预览与发布版本均使用实际 reader，不将设计样例值写入应用。
- 最终真实窗口截图覆盖中英文浅色 / 深色 620×660 pt 四张、中文浅色 / 英文深色 400×660 pt 上下四张，以及中文深色 620×520 pt 上下两张。另保存 620×1040 pt 中文完整内容图；1040 pt 仅是 DEBUG 验证夹具，正式高度仍为最多 660 pt。
- 中文浅色宽屏侧栏及英文深色窄屏内联各 29 步实际 AppKit 交互通过，覆盖 CPU / 内存标题和主数值入口、返回、Apps / Events / Settings 连续选择，以及每组五次关闭并重开。断言正确路由、同一窗口编号、位置和尺寸。进程内真实鼠标事件和原生窗口生命周期用于隔离验证，不宣称生产菜单栏外部点击 / Escape、悬停或设置值修改的 UI 覆盖。
- 当前会话无活动显示屏。PNG 来自实际 NSWindow 内生产 SwiftUI 内容的 NSHostingView 缓存捕获，未申请录屏权限、改变显示配置或系统外观；不将其称为物理桌面截图。短窗口与窄窗口底部内容滚动可达，页头与导航固定。
- 实际完整中文图 `PulseBar-1.12.0-实际中文界面.png` 已保存到 Library，`libfile_ad39f8d1ff28819196f536104b501c92` version 0，SHA-256 `b0af46e88b39d6e04eede6b1724104ee8f7c79f305ade0af0fcb2aee83651ea6`。本地图与 Library 身份元数据写回成功。
- 未安装或替换已安装应用。`/Applications/PulseBar.app` 保持 1.11.0（19），`~/Applications/PulseBar.app` 保持 1.9.0（17）；两个二进制和生产偏好文件在验收后与本轮启动基线逐字节一致。Intel、macOS 13、实体 MacBook 电池和多 GPU 真机未纳入本轮验收。

本地证据位于任务工作区 `implementation-1.12.0/validation/` 和 `implementation-1.12.0/ui-regression/`，包括来源哈希、测试 / 构建 / 采样日志、11 张 PNG 和 58 步交互结果。本条只记录发布前验收；main CI、tag release、公开 DMG 与签名更新源仍需发布后独立核验。

## 2026-10-08：v1.11.0 发布前复核

- 用户授权发布此前最终方案：只去除包住全部硬件的外卡底色与描边，保留内部硬件标题、横纵分隔和层级，无进度条，并保留英文 Events 空状态完整换行。版本更新为 1.11.0（19），英文和中文发布说明与当前布局文档同步。
- 69 项构建输入与最终 frame-free UI 验证候选相比，仅 `Resources/Info.plist` 的版本和 build 变化，其余 68 项逐字节相同。因此沿用下方 2026-10-05 最终方案的 10 张真实窗口截图和 58 步隔离交互证据；本次未重新宣称生产菜单栏外部点击/Escape、悬停或设置值修改的 UI 覆盖。
- 在独立 `/tmp/pulsebar-release-1.11.0/repo` 干净缓存下，完整 91 项测试、arm64+x86_64 release 构建、独立深度严格代码签名检查和最终 app 三次真实诊断采样全部通过。原仓库 69 项输入在验证结束后仍与构建副本一致。首次编译缓存权限失败及复用 Sparkle 缓存路径失败已保留日志，干净重建成功，系统工具链未修改。
- 本机 M4 GPU 利用率、CPU/GPU/存储温度和启动数据卷容量可用；无有效内存温度，无内置电池，缺失项按原规则省略。版本预检确认 1.11.0 和 build 19 高于远端稳定 release 与更新清单。
- 本轮未安装 app 或启动生产 GUI。启动时 `/Applications/PulseBar.app` 为 1.10.0（18），`~/Applications/PulseBar.app` 为 1.9.0（17）；本地检查后两个二进制和生产偏好文件均与本轮启动基线逐字节一致。Intel、macOS 13、MacBook 实体电池和多 GPU 真机未纳入本轮验收。

本次独立本地证据位于任务工作区 `release-1.11.0/local/`，包括 `local-verification.json`、来源哈希、测试/构建/采样日志与前置失败记录。此条为发布前本地记录；main CI、tag release、公开 DMG 与签名更新源仍需发布后独立验证。

## 2026-10-05：只移除外框，保留内部硬件分区（最终本地候选，未发布）

- 按用户最新澄清，只删除包住全部硬件指标的圆角底色和描边，恢复已验证单卡版的 CPU、内存、GPU、存储、网络及可选电池标题、分隔和层级。与已验证内部布局的 69 项输入相比，68 项逐字节相同，唯一源码差异为 `PopoverView.hardwareContent` 删除 8 行外层背景/描边；英文 Events 空状态换行修复、动态读数隐藏、全部数据、四组纯线历史和详情行为均保留，无进度条。
- 560×660 pt 中英文深浅外观四张、400×660 pt 中文浅色/英文深色上下滚动四张及 560×520 pt 中文深色上下滚动两张，共 10 张真实窗口截图经独立视检通过：正常尺寸全部当前有效指标/温度/历史/统计同屏；小屏底部完整可达，页头和导航固定，无重叠或文案省略。
- 中文浅色宽屏侧栏和英文深色窄屏内联各 29 步实际交互通过，CPU/内存标题与数值入口、返回、重复切换和每组五次窗口关闭重开保留正确路由/位置/编号/尺寸。范围为隔离预览窗口，不覆盖生产菜单栏外部点击/Escape、悬停或设置值修改。
- 最终 91 项测试、arm64+x86_64 通用构建、深度严格签名校验和打包应用三次真实采样通过，69 项输入与独立快照一致。版本仍为 1.10.0（18）；不提交、推送、发布或替换安装。两个已安装副本仍为 1.9.0（17），二进制 SHA-256 `579db2d1109ae55cb71df98ac4db596cd5ae519670b5f8f65bc4a3afda5fc7ac`，生产配置逐字节保留；预览只设置窗口外观，不写全局系统外观偏好。
- 新实际中文截图为 `PulseBar-移除外框保留分区-中文.png`，Library `libfile_abffcc429e1c819190f7041536bb1936` version 0；保存和本地身份元数据写回均成功。最终截图明确外层方框装饰已去除，内部硬件分区已恢复。证据见 `artifacts/frame-free/` 的截图矩阵、交互记录、Library 记录和 `validation/` 测试/构建/采样报告及内部候选 ZIP。

## 2026-10-05：取消内部硬件分区（已保存中间方案，已按用户澄清替代）

- 实际下载并查看用户 PNG 参考 `libfile_0329e6236e6081918a22a7b8f469eff9`（SHA-256 `b4743fef288923f6eb751b7b8ec2c7edd1b4199ccd08078792beffd25905e907`）；红框覆盖内层硬件卡。移除其背景、边框、模块大标题和横纵分割，仅保留外层面板，使用连续两列来源标签/数值网格，窄于 500 pt 时单列滚动。
- 全部现有可用数据、四组纯线历史、均值/峰值、联动查看、错误提示及 CPU/内存文字和数值详情入口保留。可选温度、GPU、容量和电池紧凑重排；真实零值保留，无可用读数不占位。生产采集、模型、偏好行为、版本及发布脚本未改；字号为标签 11 pt、数值 14 pt、CPU/内存主数值 20 pt。
- 最终 10 张真实截图覆盖中英文各深浅外观 560×660 pt、中文浅色及英文深色 400×660 pt 上下滚动、中文深色 560×520 pt 上下滚动。初版在 GPU 温度出现及英文换行时底部统计超出当前视口，已收紧间距并重新截图；最终正常宽度包含全部当前有效标量及四曲线统计，小屏内容滚动可达，页头和导航固定。
- 两组实际交互各 29 步通过：中文浅色宽屏侧栏和英文深色窄屏内联，分别点击 CPU/内存文字及数值、关闭详情、返回、重复切换与五次关闭重开，正确路由和窗口编号/位置/尺寸均通过断言。按钮由进程内真实 AppKit 鼠标事件触发，窗口生命周期使用 `performClose` 与原生重开；隔离窗口测试不覆盖生产菜单栏外部点击/Escape、悬停和设置值修改。
- 最终 91 项测试、arm64+x86_64 构建、深度严格签名和打包应用三次真实采样通过；69 项输入与独立构建快照一致。版本保持 1.10.0（18），两个安装副本保持 1.9.0（17），生产配置逐字节不变，系统外观未更改。未提交、推送、发布或替换安装。
- 最终实际中文截图保存为 `PulseBar-连续指标网格-中文.png`，Library `libfile_f30b75e8235c819194d219eba5d763eb` version 1；本地身份与版本元数据已成功写回。证据见 `artifacts/flat-grid/` 的截图矩阵、Library 记录、实际交互报告及 `validation/` 构建日志和本地候选 ZIP。

## 2026-10-05：单卡布局深色与详情补充回归（本地，未发布）

- 在 UUID 独立配置和临时事件目录中，仅对预览窗口与 hosting view 设置 DarkAqua；未改变系统外观、用户配置或两个已安装应用。正常宽度保留真实屏幕可用宽度，详情扩为 881 pt 侧栏；400 pt 预览使用既有内联详情降级。
- 中文 560×660 pt 深色总览、881×660 pt 详情，以及英文 400×660 pt 深色内联详情共两组各 29 步通过。按钮经进程内真实 AppKit 鼠标事件触发，覆盖 CPU/内存标题和数值入口、详情关闭、总览返回、Apps/Events/Settings 重复选择；每组还通过 `performClose` 与重开检查五次窗口生命周期，包含四种详情打开时关闭并重开回总览。窗口编号、位置、内容尺寸和路由逐步断言通过。
- 两组各六张实际窗口 PNG 经主代理和独立代理视检：深色文字、数值、单位、四组曲线及分隔可读，正常宽度全部当前可用指标同屏。发现英文窄屏事件页空状态说明截断，已以自然换行修复；最终截图显示完整文案，两组 58 步按最终源码重新通过。窄屏详情继续沿用滚动容器，未宣称所有详情底部内容同时可见。
- 最终修复后完整 91 项测试、arm64+x86_64 通用构建、深度严格签名校验及打包应用三次真实采样通过，69 项输入与独立构建快照一致。生产 UI 仅追加事件空状态文字换行，其他新增回归逻辑均在 DEBUG 预览内。
- 两个安装副本仍为 1.9.0（17），二进制 SHA-256 均为 `579db2d1109ae55cb71df98ac4db596cd5ae519670b5f8f65bc4a3afda5fc7ac`；生产偏好文件与补查前逐字节一致，系统外观偏好仍未设置。本轮未提交、推送、发布或替换安装，版本保持 1.10.0（18）。
- 本次隔离回归不覆盖生产菜单栏锚点、外部点击/Escape、悬停、设置值修改和窄屏详情底部滚动操作；Intel/MacBook/多 GPU 真机不在本轮范围。

补充证据见 `artifacts/single-card/regression/` 的两组 `interactions.json`、12 张深色 PNG 和 DEBUG 构建日志；最终构建证据及本地 ZIP 在 `artifacts/single-card/validation/`，统一核验结果为 `artifacts/single-card/final-verification.json`。以下首次单卡截图记录的深色和详情交互边界，由本条补充记录更新。

## 2026-10-05：统一总览卡片（本地可审阅，未发布）

- 基于已发布 main `4a8c874229bd80b4c172d6e65d72cf3628ac77f6`，保留版本 1.10.0（18）。本轮不提交、推送、打标签、发布或替换安装副本。
- 总览改为一张统一外卡：560 pt 双列，上方 CPU/GPU 与内存/电池，下方存储与网络；高度最多 660 pt。所有现有可用指标及四组历史保留，缺失读数继续隐藏。移除唯一存储 ProgressView 和历史曲线面积填充；正文/统计 11 pt、主数值 20–22 pt，不以缩小文字换取压缩。
- 最新导航及定位尺寸测试使用 560/881 pt；完整 91 项测试通过。69 项源码、测试、资源、脚本及 Package.swift 与独立 `/tmp/pulsebar-single-card-validation/repo` 快照完全一致。arm64+x86_64 通用构建与深度严格代码签名校验通过，打包应用三次真实采样无 errors，M4 GPU、CPU/GPU/存储温度和启动卷容量有效；内存温度缺失、内置电池为 `null`。
- 隔离 DEBUG 应用包使用真实 reader、UUID 独立配置与临时事件目录；不启动生产实例、更新器、通知回调或登录项。首次从裸调试二进制启动的预览因 macOS 应用包要求失败，不计成功验证；补齐临时应用包后，中英文 560×660 pt、中文 560×520 pt 上下滚动、英文 400×660 pt 单列上下滚动共六张真实 PNG 均通过主代理和独立审查。正常尺寸全部当前可用指标同屏；小屏下方内容可达，标题与导航位置固定；所有 PNG 不透明。
- 六张截图以 image 保存到 Library，各项 succeeded，返回身份元数据已回写本地。生产采样、模型、配置、资源与版本、发布脚本未改；本轮未使用用户事件文件作为测试存储。
- 未真机验证：Intel、macOS 13、MacBook 电池、多 GPU。深色外观及本轮 Apps/Events/Settings 与悬停的实际交互未纳入这次截图矩阵；相关显示条件和交互逻辑保留。既有 ad-hoc 签名不等同 Apple notarization。

证据位于 `artifacts/single-card/`，包含六张实际运行截图、Library 文件记录及 `validation/` 下的测试/构建/采样日志、69 项哈希、核验报告和本地候选 ZIP。采样和已保存配置的行为没有修改。

## 2026-10-05：硬件模块改版（本地候选，未发布）

- 基于 main `6aff86f3e226ade01d2cc3f798a2f727dd2d3e4a`，按 CPU、内存、GPU、存储、网络、内置电池分区，温度归各硬件标题。版本仍为 1.9.0（17）；本轮没有提交、推送、打标签、创建 release 或更新安装副本。
- 使用现有 CLT/Swift 6.0.3 兼容脚本；Documents 工作目录出现构建期间文件时间戳变化，失败尝试不计通过。最终相同源码在 `/tmp/pulsebar-hardware-20261005/repo` 顺序构建，69 项源码、资源、脚本和 Package.swift 哈希一致；完整 91 项测试通过，包含电池来源/容量单位/状态/时间哨兵、GPU 无效值和分设备百分比、卷容量边界及原有配置、历史、事件、导航测试。
- 最终 `scripts/build-app.sh` 完成 arm64+x86_64 通用候选，深度严格签名校验与架构检查通过。采用既有本地 ad-hoc 签名；没有增加权限、服务、凭据或签名证书。
- 生产 `--sample 3` 无 errors，Apple M4 GPU 利用率有真实有效值，启动数据卷容量有效，电池为 `null`，CPU/GPU/存储温度有效，内存温度缺失。13 秒真实后台检查获得 CPU/磁盘各 13 个样本，内存/网络/Swap 各 14 个样本，事件读回一致，停止后 GPU/容量/电池/温度全部清空。
- 隔离 DEBUG 预览使用真实 reader、独立配置与事件目录，不启动更新、通知回调、登录项或生产实例锁。英文、中文上半部/下半部及 660 pt 较矮窗口实际渲染均独立视检通过；固定页头和导航保持位置，下半部含完整网络曲线、累计、网卡。截图是运行窗口内容，不含无关桌面或电池测试数据。
- 中文上下截图已作为 image 成功保存到 Library，上传用文件与最终视检 PNG 字节完全一致；文件身份元数据写回成功，两项从 Library 重新下载后的 PNG 与原图逐字节一致。Library 预备上传后端明确不可用且没有创建上传会话，随后按技能规定改用可用的本地文件创建批次；两项均返回 succeeded。
- 原安装副本二进制 SHA-256 保持 `579db2d1109ae55cb71df98ac4db596cd5ae519670b5f8f65bc4a3afda5fc7ac`，配置前后完全一致（跟随系统、2 秒刷新、12 小时历史、四项菜单、事件通知开启）。原事件文件未作为测试存储使用；真实应用持续运行产生的新事件不被删除。
- 边界：Intel 与 MacBook 电池尚未真机验证。数据不可获取时各可选字段降级隐藏；测试不能证明其他机型传感器可用。原生 UI 连接一次异常耗时约 10 分钟，其余视觉验证用本应用真实窗口的隔离渲染完成，未宣称交互工具覆盖所有按钮/屏幕配置。

证据位于 `artifacts/hardware-modules/`：`tests.log`、`universal-build.log`、`diagnostic.ndjson`、`live-monitor.json`、`source-hashes.json`、`overview-zh-top.png`、`overview-zh-bottom.png`、`overview-en.png`、`overview-zh-compact.png`、`library-delivered.json`、本地候选与 `change.patch`。设计与接口见 [HARDWARE-MODULES.md](HARDWARE-MODULES.md)。

## v1.6.0 build 12：真实应用图标

2026-09-15：应用排行与历史事件共用真实图标组件，从记录的应用包路径读取 macOS 原生图标，缓存最多 128 项；无应用路径或路径已不存在时保留通用图标。Release 构建、安装包及安装副本严格签名校验通过，已安装到 `~/Applications/PulseBar.app`。原生界面确认实时内存排行显示 ChatGPT、Code、微信图标；展开用户截图对应的 10:15:17 历史事件，确认微信、钉钉、ChatGPT、汽水音乐、Code 均显示真实彩色图标。未更改用户配置或事件数据，未推送。制品、旧版备份、构建日志与 SHA-256 位于 `artifacts/app-icons-12/`。

## v1.6.0 build 11：固定窗口定位与 Swap 安装

验证日期：2026-09-15。

- 用同一个 NSPanel 取代展开时重建的 NSPopover，取消系统弹窗与手动窗口移动两套定位逻辑。打开时记录菜单栏锚点，设置向右展开；靠屏幕边缘时做必要的边界调整。Escape 和点击外部收起，下次打开设置默认折叠。
- 55 项测试通过，新增侧栏展开/收起保持原点、屏幕边缘和负坐标显示器边界测试；Release 构建及安装签名校验通过，实际安装为 `~/Applications/PulseBar.app` 1.6.0（11）。
- 已在安装版本点击设置展开、收起及 Memory 详情，并读取实际窗口位置：总览 `(1154,590,400,640)` → 设置 `(1154,590,661,640)` → 总览 → 内存详情 `(1154,590,741,640)`。后续正常采样读取的窗口 frame 同样保持原点，没有跳到左侧。完整界面显示标题、四类图表、累计及底部操作；Swap 总览显示 5.4 GB，Memory 详情显示用量、变化量与曲线。
- 额外尝试连续切换时 UI 工具返回 `noWindowsAvailable`，未将这次尝试计为成功复测。保留截图观察和窗口坐标记录的验证边界，不宣称所有显示器/系统切换场景已验收。
- 保留跟随系统语言、2 秒刷新、12 小时历史、四项菜单显示；开机启动和事件通知保持关闭。旧版备份、正式 ZIP、测试/构建日志、运行坐标及 SHA-256 位于 `artifacts/panel-1.6.0/`。未推送此次修改。

## v1.5.1：弹窗定位修正（用户复测失败）

验证日期：2026-09-15。环境：macOS 26.6.2，Apple Silicon；当前屏幕 2240 × 1260 pt。

**更正：以下当时的单窗口截图不足以证明屏幕位置正常。用户随后再次复现展开设置跳到屏幕左侧，1.5.1 不视为已解决定位问题。**

- 修正首次打开时重复创建弹窗的问题：去重先于丢弃初值，异步布局任务只处理发起时的当前弹窗，已关闭窗口的任务不再作用于后来打开的窗口。诊断中，修正前曾在 0.093 / 0.052 秒内重复创建同一状态的窗口，修正后对应检查未再发生。
- 取消每次采样对定位矩形的重复赋值；重新打开时更新菜单栏锚点，窗口移动或调整尺寸后按按钮的屏幕坐标重新对齐，并限制在当前屏幕可见范围。弹窗禁止独立移动。位置校正只在窗口事件发生时执行，不增加采样定时器。
- 实际最终安装版确认默认面板、展开设置及关闭后重新打开都能完整显示标题、四项数据、四类曲线、累计和底部操作，无滚动区域；重新打开默认折叠，输入框没有保持焦点。自动化工具在更换窗口时曾返回失效窗口错误，重新获取当前窗口后完成检查。
- 正式版 1.5.1（build 10）已安装并运行。ZIP 解压后及安装副本严格签名验证通过，已签名二进制 SHA-256 一致：`6484730c072d3b4f54d25183ed9c4da15751beb15d964e364ffb7204d118bbfc`。正式包不含临时坐标日志；原安装包备份、测试 / 构建日志、诊断记录和修正版 ZIP 均位于 `artifacts/popover-position-1.5.0/`。
- 用户当前设置保留：跟随系统语言、2 秒刷新、12 小时历史范围、四项菜单显示全部开启、开机启动关闭。本次只安装定位修正；其他正在开发的 1.6 功能保留在工作目录。

## v1.6.0：应用排行、内存压力、联动查看与事件

验证日期：2026-09-14。环境：macOS 26.6.2，Apple Silicon。当前状态：代码与构建验证完成，实际界面验收及安装待解锁后继续。

- 53 项测试通过。新增覆盖应用 / 辅助进程归组、前五名排序、PID 复用、CPU 时钟换算及实际进程 CPU 时间对照、采样中断、图表两端裁剪、实际样本查找、时间加权均值、持续事件去重与升级、独立通知冷却、事件快照持久化和保留边界。日志：`artifacts/pulsebar-1.6/tests.log`。
- 真实进程采样发现 `proc_pid_rusage` 返回 Mach tick；本机时基为 125/3 纳秒。实现已换算为纳秒，使用进程自身 CPU 时间的实际计算测试验证，避免将占用率低估约 41.7 倍。
- 后台集成检查运行真实 `SystemMonitor` 13 秒，在隔离临时目录验证采样计时器、后台排行和事件存储。获得 CPU / 磁盘各 13 个样本，内存 / 网络 / Swap 各 14 个样本，采样 772 个可访问进程；系统持续偏高的内存压力触发 1 条真实事件，包含 CPU / 内存各 5 项应用快照，落盘读回一致。未触发通知授权，未写入用户事件文件。证据：`artifacts/pulsebar-1.6/monitor-integration.json`；可在 Debug 构建运行 `.build/debug/PulseBar --verify-insights` 复查。
- 最终 Release 为 1.6.0（build 10）。ZIP 在同步目录外解压，严格签名验证通过，解压与 dist 二进制 SHA-256 一致：`1f769bed972403c51bfaa70dc119209a4faa755c177e34cdc06b8f18b4f1c44a`。构建、制品校验与源码清单位于 `artifacts/pulsebar-1.6/build.log`、`artifact-verification.json`、`source-sha256.json`。
- 最终制品的三次真实诊断采样无 errors；末次采样 736 个可访问进程、跳过 189 个退出或不可访问进程，CPU / 内存排行均有数据。系统压力为 2（偏高），Swap 用量为 4,481,482,752 字节。证据：`artifacts/pulsebar-1.6/live-samples.ndjson`。
- **实际界面验收待完成**：两次原生 UI 工具检查均返回 Mac 锁屏且自动解锁失败，已请求用户手动解锁。尚未验证 640 pt 总览、CPU / 内存侧栏、四图共享悬停游标、空数据提示、事件展开、中英文及设置切换时的最终界面，也未验证系统通知横幅。不要把静态测试或采样结果视为这些交互已验收。
- **未替换 Applications 中的安装版本**。解锁后先验证最终候选，保留原安装包备份，再替换、启动并核对签名及二进制 SHA-256；检查活动监视器入口、事件重开保留及面板收起 / 展开不裁切。通知默认关闭；保留用户原有设置，完成临时语言 / 时长测试后恢复。

## v1.5.0：折叠设置、登录启动与无滚动面板

验证日期：2026-09-14。环境：macOS 26.6.2，Apple Silicon。

- 本次功能的独立源码快照通过 36 项测试，包含登录项真实状态、重复请求、待批准、失败恢复及外部系统设置变更；设置中英文资源检查通过。因同一工作目录同时有其他功能正在修改，快照只包含本次布局和登录项相关改动；文件清单与 SHA-256 位于 `artifacts/pulsebar-1.5/scoped-source.json`，测试日志为 `tests-scoped.log`。
- Release 构建完成，版本 1.5.0（build 9）；ZIP 在同步目录外解压后严格签名校验通过。最终候选二进制 SHA-256：`708fe31133d66625c59d17353aa4537e64427c674e82987ebbbab37079258282`。安装包为 `artifacts/pulsebar-1.5/PulseBar-1.5.0.zip`；构建日志为 `build-scoped.log`。三次真实采样无错误，CPU、内存、磁盘和网络均有有效数据，原始结果为 `live-scoped.ndjson`。
- 先前候选版本已经实际验证：所有配置移至设置侧栏；四项显示开关、语言、刷新、小时范围与开机启动可见；主面板没有滚动区域，四类数据、曲线和累计均可见。通过实际开关操作，系统登录项记录先变为 enabled，关闭后变为 disabled，证据为 `login-item-enabled.txt` 和 `login-item-disabled.txt`。没有注销或重启 Mac。
- **最终界面验证待完成**：先前候选版展开设置时发现顶部偏移，最新实现改为按宽度重新创建、定位弹出面板。Mac 随后锁屏，尚未验证此修正后的完整截图，也未将最终候选包替换到 Applications。当前安装版本的二进制为 `bc27dd88e6b42616297cbb9dd341fac4600a2ae3ca71b2d58d3ef5f37761fcf7`。解锁后需验证折叠 / 展开 / 重新打开均没有裁切且默认收起，并将测试语言从简体中文恢复为跟随系统。刷新 2 秒、范围 1 小时、四项显示全部开启，开机启动已恢复关闭。

## v1.4.1：自动汇总单位与编辑焦点

验证日期：2026-09-14。环境：macOS 26.6.2，Apple Silicon。

- 31 项测试通过。新增容量 / 累计的十进制自动单位、单位晋级时的舍入边界、UInt64 最大值、内存已用 / 总量共用单位；中英文容量模板均通过，实时速率继续固定 MB/s、一位小数。
- Release 构建和本机安装完成，版本 1.4.1（build 8）。安装 App 严格签名校验通过，二进制 SHA-256 与 dist 版本一致：`51e27db2777da3323d951c2d558fa0ea0b22ff3c9b76a3c17cdea03dd68de2de`。旧版备份和本次测试 / 构建日志位于 `artifacts/pulsebar-1.4.1/`。
- 实际界面确认内存显示 `21.5 / 25.8 GB`，分类说明自动采用 GB；磁盘累计从 MB 自然增长到 `1.2 GB`，网络累计先显示 `297.0 KB / 74.8 KB`，随后显示 MB。默认面板仍完整展示四类曲线和底部设置。
- 打开面板时辅助功能焦点为 popover，截图中两个输入框都没有蓝色焦点框。点击 History 可正常编辑；按 Return 后焦点回到面板，Refresh 也验证通过。按 Tab 可聚焦第一个开关，原生键盘导航保留。
- History 输入 `0.5` 后点击标题，焦点退出输入框且四类曲线切换为 30 分钟；在编辑状态输入 `0.5` 后直接关闭、重新打开面板，也确认保存为 30 分钟且未恢复选中。随后恢复原来的 `1 hour`；最终刷新为 2 秒、语言跟随系统、四项显示开关全部开启。
- 应用保持运行，验证结束后收起面板。容量较大时的 TB / PB / EB 晋级由合成数据测试覆盖。

## v1.4.0：hour 配置、默认可见的网络图、一位小数

验证日期：2026-09-14。环境：macOS 26.6.2，Apple Silicon。

- 29 项测试通过，覆盖一位小数的单位与舍入、小时输入换算和非法数字处理、旧秒数配置往返换算、24 小时保留边界，以及限制绘制点数时保留网络双向峰值。
- Release 构建与本机安装完成，版本 1.4.0（build 7）。安装 App 严格签名校验通过，二进制 SHA-256 与 dist 版本一致；旧版备份位于 `artifacts/pulsebar-1.4/PulseBar-1.3.0.zip`。
- 实际 App 中 History 的单位显示为 `hour`。输入 `0.5` 后，四类曲线均显示最近 30 分钟，刷新仍为 1 秒；随后恢复原来的 5 分钟时长，字段显示 `0.0833 hour`，保存值仍为 300 秒。
- 默认打开面板且滚动位置为 0 时，截图确认 CPU、内存、磁盘和网络曲线同时可见。网络图显示蓝色下载与绿色上传双折线，累计、网卡及底部设置也完整显示，无需向下滚动。
- 真实读数确认百分比、MB、MB/s 统一一位小数，例如 `29.8%`、`21371.4 / 25769.8 MB`、`43.9 MB/s`；微小非零速率显示 `<0.1 MB/s`。
- 应用保持运行；最终核对时取样时长为 300 秒、刷新为 2 秒，语言和四项显示设置保留。测试和构建日志位于 `artifacts/pulsebar-1.4/tests.log`、`build.log`。24 小时保留边界通过合成采样验证。

## v1.3.0：脉动 · PulseBar、自定义曲线范围、两位小数

验证日期：2026-09-14。环境：macOS 26.6.2，Apple Silicon，24 GiB 内存。

- `./scripts/swift-local.sh test --disable-xctest`：27 项测试通过。新增验证按实际时间截取曲线、双向数据的边界插值、缩短后重新扩大范围复用已有采样、空历史、1 小时保留上限，以及范围设置与刷新间隔分别保存。数字格式覆盖零值、微小非零值、舍入边界、大数、百分比和内存用量的两位小数。
- Release 构建通过，版本 1.3.0（build 5），生成 `dist/PulseBar.app` 和 `dist/PulseBar.zip`。已安装到 `~/Applications/PulseBar.app`，严格签名校验通过，安装与 dist 的已签名二进制 SHA-256 一致；中英文资源位于 App 内的 `PulseBar_SpeedCore.bundle`。
- 实际启动后英文标题为 PulseBar，切换简体中文后标题为“脉动”。旧版四项显示、跟随系统语言和 1 秒刷新设置保留。旧安装副本与 ZIP 备份移至 `artifacts/pulsebar-1.3/`，原 `~/Applications/NetSpeed.app` 已替换为新名字。
- 通过实际 App 将取样范围设为 300 秒，四类曲线说明和时间轴均切换为最近 5 分钟，刷新仍为 1 秒。改为 10 秒时磁盘纵轴随可见窗口缩放；再扩大到 300 秒时已有历史仍可使用。
- 退出并重新启动最终安装版本，确认取样范围仍为 300 秒、刷新为 1 秒、语言跟随系统、四项全部显示。最终截图确认完整内存读数（例如 `21412.10 / 25769.80 MB`）、百分比及 MB/s 读数均保留两位小数，底部设置和退出按钮完整可见。
- 使用与 App 相同的 `MenuBarLabel` 原生绘图代码，检查全部指标与四种单项布局。`100.00%`、`9999.99 MB/s` 和 `<0.01 MB/s` 的字体边界均在列宽内，截图无重叠或截断；更长数字由实际字形宽度扩展菜单栏。预览位于 `artifacts/pulsebar-1.3/menu-label-preview.png`。
- 最终应用保持运行，当前取样范围为最近 5 分钟。测试与构建日志分别保存在 `artifacts/pulsebar-1.3/tests.log`、`build.log`。

1 小时历史边界通过合成采样验证；没有等待 1 小时运行来替代该测试。未进行其他架构 / macOS 13 真机兼容测试，也未进行 Developer ID 签名、公证或对外发布。

## v1.2.0：显示开关、多语言、刷新间隔与固定 MB

验证日期：2026-09-14。环境：macOS 26.6.2，Apple Silicon，24 GiB 内存。

- `./scripts/swift-local.sh test --disable-xctest`：24 项测试通过，覆盖全部 15 种非空显示组合、最后一项保护、偏好持久化及非法值恢复、中英文资源完整性与错误提示切换、固定 MB / MB/s 格式，以及 6 / 10 / 30 / 60 秒采样和缩短刷新周期后的速率与累计。
- Release 构建通过，版本为 1.2.0（build 4）；中英文资源随 App 一起打包。已安装到 `~/Applications/NetSpeed.app`，安装副本的严格签名校验通过，二进制 SHA-256 与 dist 中已签名版本一致。
- `--sample 3 --interval 6` 真实采样无错误，两个实际间隔为 6.011 秒和 6.010 秒；首个采样建立基线，后续 CPU 为 20.95% 和 15.61%，磁盘读取约 2.441 MB/s 和 0.141 MB/s，长间隔未被误判为采样停顿。原始数据位于 `artifacts/settings-1.2/interval-6s.ndjson`。
- 通过实际 App 操作四个开关，验证仅网络和仅 CPU 的组合：最后一项保持开启且禁用，并显示保留至少一项的提示。隐藏的指标仍在展开面板中正常显示读数和曲线。
- 实际切换简体中文与 English，截图检查标题、控件、说明和数字布局；速度显示 MB/s，内存已用 / 总量和累计显示 MB。界面内不再提供 B/s / b/s 单位切换。
- 刷新字段输入 6 后，标题、字段和步进器均显示 6 秒；输入 0 后自动限制为 1 秒。退出并重新启动 App，确认仅网络、English、6 秒三项设置同时保留，且读数持续更新。
- 验证结束后恢复四项全部显示、跟随系统语言、1 秒刷新，应用保持运行。旧版安装备份位于 `artifacts/settings-1.2/NetSpeed-1.1.0.zip`。

本次为本机更新，未进行其他架构 / macOS 13 真机兼容测试，也未进行 Developer ID 签名、公证或对外发布。

## v1.1.0：CPU、内存、磁盘 I/O

验证日期：2026-09-14。环境：macOS 26.6.2，Apple Silicon，24 GiB 内存。

- `./scripts/swift-local.sh test --disable-xctest`：16 项测试通过。新增覆盖 CPU 采样区间与多核归一化、32 位 tick 回绕、无效时间和休眠基线；4 KiB / 16 KiB 内存页换算、缓存扣除和压缩页统计；磁盘 64 位计数、多设备聚合、BSD 名称复用、重接入、计数器重置、休眠和重置。
- `./scripts/build-app.sh`：Release 构建及暂存目录内 ad-hoc 签名校验通过，生成 `dist/NetSpeed.app` 和 `dist/NetSpeed.zip`。安装到 `~/Applications/NetSpeed.app`；安装副本 `codesign --verify --strict` 通过，二进制与 dist 中已签名的二进制 SHA-256 一致。
- 12 次真实采样没有读取错误，CPU 为 21.6%–50.7%，内存总量 24 GiB；识别 `disk0`、`disk6`、`disk8`，与 `iostat` 列出的物理设备一致。首个 CPU 与磁盘速率为 null，后续正常产生速率。
- 受控磁盘验证：只在项目 artifacts 中创建临时文件，禁用该文件的数据缓存，写入 64 MiB、执行 F_FULLFSYNC 后读取 64 MiB，完成后移除测试文件。采样窗口累计读取 764,534,784 B、写入 89,350,144 B，读取峰值 243.2 MB/s、写入峰值 72.4 MB/s。数值包含整台 Mac 同期后台 I/O，不能归因于测试文件本身。
- 实际 App 的辅助功能与截图检查：CPU、内存已用 / 总量、磁盘读写、网络读数和四类曲线正常；网络切到 b/s 后，磁盘仍为 B/s；重置清空网络和磁盘累计、曲线重新开始。最终恢复 B/s。
- 展开面板最终限制为最多 560 pt 高：重置后截图确认标题和操作区没有被裁切；执行 Scroll Down 后滚动条到达 1，网络完整曲线、累计和网卡可见，标题及重置 / 退出仍固定显示。
- 菜单栏通过与 App 相同的 `MenuBarLabel` 原生绘图代码渲染，检查 100.0% 和最长速率文本，三组双行读数没有重叠或截断。
- 原始数据：`artifacts/system-monitor/live-samples.ndjson`、`live-summary.json`；原生标签图：`menu-label-preview.png`；旧 App 副本也保留在该目录。这些本地验证材料不进入版本控制。

休眠、拔插和计数器异常通过合成采样测试；没有为了验证而中断本机网络、拔出磁盘或强制休眠。未进行其他 Mac 架构 / macOS 13 真机兼容测试，也未进行 Developer ID 签名、公证或对外发布。

## v1.0.0：原始网络监控

验证日期：2026-09-14。环境：macOS 26.6.2，Apple Silicon，Swift 6.0.3。

- `./scripts/swift-local.sh test --disable-xctest`：7 项测试通过，覆盖 64 位计数、实际采样间隔、多网卡聚合、网卡切换和断线重连、计数器重置、休眠间隔、物理网卡筛选、单位换算与舍入。
- `./scripts/build-app.sh`：Release 构建通过，生成本机架构的 App 和 ZIP。应用在临时目录完成本地签名，避免同步目录自动添加的 Finder 元数据干扰签名。
- 安装到 `~/Applications/NetSpeed.app`，已实际启动。
- 真实网络采样 12 次：识别已连接的 `en0` 和 `en1`，排除未连接的 `en2` 至 `en5`。
- 同时下载 5,000,000 字节公开测试数据，HTTP 200，下载平均速度 1,048,626 B/s。采样窗口记录总接收 6,436,864 字节、总发送 7,451,648 字节，下载峰值 3.288 MB/s、上传峰值 2.538 MB/s。统计覆盖整台 Mac，因此包含已有后台流量，不将它等同于单个下载任务的速度。
- 使用真实 App 截图和辅助功能界面检查：双向速度、一分钟曲线、累计流量、网卡名称正常显示；切换到 b/s 后显示 Mb/s 和 Kb/s，切回 B/s 后恢复；重置后两向累计和曲线归零。
- 最终默认恢复 B/s。程序保持运行，不自动添加登录项。

原始采样保存在本地 `artifacts/live-samples.ndjson`，该目录不进入版本控制。本次未进行其他 Mac 架构或 macOS 13 真机兼容测试，也未进行 Developer ID 签名、公证或对外发布。
## v1.7.0：GitHub 下载与签名更新

验证日期：2026-09-15。发布提交：`21c35817d5089181ef6b6f2689a5a74c74cac8e6`，tag：`v1.7.0`，build：`13`。

- 本地及 GitHub macOS 15 ARM64 Runner 的 55 项测试通过，arm64 / x86_64 通用 App 构建与真实诊断采样通过。
- [CI](https://github.com/monaco-io/PulseBar/actions/runs/34923194689) 和 [正式发布工作流](https://github.com/monaco-io/PulseBar/actions/runs/34923369168)均成功。仓库已公开，[1.7.0 Release](https://github.com/monaco-io/PulseBar/releases/tag/v1.7.0)为非草稿、非预发布的 Latest。
- DMG、ZIP、appcast、SHA256SUMS、安装说明和版本说明六个附件均可匿名下载，HTTP 200；版本、构建号、最低系统版本、ZIP 长度及 SHA-256 一致。DMG 只读挂载成功，Applications 链接正确，App 深度严格签名校验通过。
- 使用 Sparkle 工具对实际公开下载的 feed 和 ZIP 做密码学校验，均通过。本地对两种文件各篡改一个字节后，校验均拒绝。
- 升级端到端验证：隔离源码副本仅降低本地版本为 `1.6.99 (12)`，并增加定时调用现有 `SoftwareUpdater.checkForUpdates()` 的测试入口；此副本未上传。原生控制工具无法稳定操作监控 App 的无标题栏 NSPanel，因此本次没有把自动点击设置入口计为通过。
- 标准 Sparkle 更新窗口实际显示“1.7.0 is now available—you have 1.6.99”及版本说明。通过原生 UI 点击 **Install Update**，看到 **Ready to Install**，再点击 **Install and Relaunch**，App 成功安装并重启。Sparkle 日志确认 feed 和 update 的 EdDSA 签名均有效。
- 更新后的 `~/Applications/PulseBar.app` 为正式 `1.7.0 (13)`，严格签名通过，程序二进制 SHA-256 为 `b93eb3de14cb602f0a88bd0485a40911357983577e9886fbfc7b32ac923dcc10`，与公开 ZIP 完全一致，确认已移除测试入口。原有 English、2 秒刷新、12 小时范围及 3 条本地事件仍在。
- 本地证据：`artifacts/github-v1.7.0/`、`published-artifact-verification.log`、`update-signature-verification.log`、`update-e2e-verification.json`、`update-e2e-sparkle.log`。

当前使用 ad-hoc 签名和 Sparkle Ed25519 更新签名，没有 Apple Developer ID 公证。未进行 Intel / macOS 13 真机验收。旧版本需手动安装 1.7.0 一次才具备更新入口。


## v1.7.1: DMG-only releases and English public information

Verified on 2026-09-15. Release commit: `71c753ad2e56d5f3cd52cdca3db097f5bb2ed921`; tag: `v1.7.1`; build: `14`.

- [CI](https://github.com/monaco-io/PulseBar/actions/runs/34924883604) and the [release workflow](https://github.com/monaco-io/PulseBar/actions/runs/34924886120) passed, including 55 tests, universal arm64/x86_64 builds, packaged sampling, and DMG/feed checks.
- The public Release contains exactly one uploaded asset, `PulseBar.dmg`, and the signed feed is hosted on `codex/updates`. Anonymous downloads returned HTTP 200. Public DMG SHA-256: `374c07ffe05930aaeb3ded208ac65ab22805fba563f540f5694d2a8d08798f4a`. The mounted app passed deep strict signing and architecture checks. Both signatures were verified with Sparkle tools.
- A local fixture reused the earlier test-only timed call to the existing update handler, reporting version 1.7.0/build 13 with the new feed URL. Sparkle displayed 1.7.1 as available and downloaded the DMG. Installation and relaunch completed; Sparkle logs confirm valid feed and update signatures. This did not verify an automated click through the borderless Settings panel.
- The running app in `~/Applications/PulseBar.app` is the official 1.7.1/build 14. Its binary SHA-256 is `aab43c228c6b4f73481ee1c34a97c8bbdcdeb151c3e1d19c0b5241bdca553749`, identical to the public DMG. Deep strict signing passed; language, refresh, history, and menu bar preferences were preserved. All six pre-update events remain. The installed app contains no test entry point.
- At the user's request, the old v1.7.0 Release and its attachments were removed after verifying that the public feed points to v1.7.1. Only the v1.7.1 Release remains. Its two automatic source archive links are generated by GitHub.
- Default README, release notes, installation documentation, and release guidance now use English, with separate Chinese documents behind explicit links. The English update-feed description is re-signed without changing the DMG enclosure or public artifact. Installation.txt uses an English filename in future packages; the already-published DMG is unchanged.
- Local evidence: `artifacts/github-v1.7.1/`, `dmg-published-verification.log`, `dmg-update-e2e-verification.json`, `dmg-update-sparkle.log`, and `english-update-feed/`.

Versions 1.7.0 and earlier require one manual installation to migrate to the new feed. Apple notarization and Intel/macOS 13 hardware testing remain outside the completed validation.


## v1.8.0: stable panel navigation and UI refinement

Verified locally on 2026-09-15, macOS 26.6.2 on Apple Silicon. Build `15`; not published to GitHub.

- 59 tests passed, including repeated tab selection, constant detail widths, narrow-display layout decisions, placement bounds, and existing monitoring/localization regressions. Both arm64 and x86_64 release builds succeeded. Three installed-app diagnostic samples returned no errors.
- Installed `~/Applications/PulseBar.app` is 1.8.0/build 15. Its binary SHA-256 is `fb2aa095a5efb283203027b6b63688f6282a7575811c373be0900ea10c4f23f2`. Deep strict signing passed, and the installed binary matches the mounted DMG. DMG SHA-256: `49ae943e2a62883271b1d046899ba835ded06217ff45c0ad97928b3901bd25be`. The local package shows only PulseBar.app and the Applications shortcut. Its hidden Finder template sets two 256-point icons in an 800 × 440 window; the mounted template matches byte-for-byte. Feed and archive signature verification passed.
- Native screenshots confirmed all four chart groups and the complete bottom navigation. A transient row offset observed during AppKit frame interpolation was removed by committing geometry atomically. The final Settings → Apps → Settings sequence retained one window, origin, and 721 × 660 pt frame, with no intermediate dismissal or incorrect frame in the diagnostic trace. Overview remains 400 pt wide.
- Native interaction checks covered CPU/Memory app tabs, event expansion, More and language menus, menu cancellation without dismissing the panel, selecting Chinese, and restoring Follow System. The final installed build also saved a changed Refresh value when leaving Settings and restored 2 seconds on Return, releasing editor focus.
- The extended final shortcut sweep could not be repeated after the Mac locked. Earlier checks verified Command-2 and Escape returning to Overview. The native automation interface automatically reopens the app when querying a hidden panel, so dismissal evidence uses the window lifecycle log. The new status-item right-click menu was not separately exercised through UI automation. Narrow-display behavior is covered by layout tests; system Reduce Motion/Transparency handling was reviewed without changing global preferences.
- Original menu bar, language, refresh, history, and notification preferences were preserved. All nine pre-upgrade events remain. Previous app versions and preference snapshots are retained in the temporary directory recorded by `artifacts/ui-1.8-qa-path.txt`.
- Evidence: `artifacts/ui-1.8-tests.log`, `ui-1.8-release-build.log`, `ui-1.8-package.log`, `ui-1.8-live-sample.ndjson`, `ui-1.8-stable-layout.log`, and `ui-1.8-verification.json`. Native UI captures are in the task's tool results.

- Final packaging follow-up: the first-launch refresh default is 2 seconds; the existing preference test verifies this and preserves custom saved intervals. English precedes Simplified Chinese in the language enum used by the menu. All 59 tests passed again, both architectures rebuilt, and three installed-app diagnostic samples returned no errors. A native screenshot confirms Refresh 2 and Every 2 s in the final installed build. The language-menu check stopped when the automation interface reported noWindowsAvailable; Finder preview returned cgWindowNotFound, so the DMG layout was verified from its mounted metadata without a Finder screenshot. Evidence: `artifacts/ui-1.8-final-tests.log`, `ui-1.8-final-build.log`, `ui-1.8-final-package.log`, and `ui-1.8-final-sample.ndjson`.

- Release preflight follow-up: native Finder initially fell back to small icons because the icon-view plist omitted its RGB background fields. Including all three fields made Finder apply the 256-point icon size and 16-point labels; a native screenshot verified the two large icons. The release template now includes those fields. GitHub CI for source commit `5c33e2833c7856f13ee47f84c5882b5cc92f9c18` passed all 59 tests, universal builds, and packaged sampling.


## v1.8.0: published release verification

Published on 2026-09-15 from tag `v1.8.0`, commit `c2fb859fd2a5756bef0bab875ba7ac7266b9b1e5`, build `15`.

- [Final CI](https://github.com/monaco-io/PulseBar/actions/runs/34935042784) and [Publish release](https://github.com/monaco-io/PulseBar/actions/runs/34935055536) succeeded. The release workflow passed 59 tests, built arm64 and x86_64, sampled the app, and verified the mounted DMG and signed feed before publishing.
- [PulseBar 1.8.0](https://github.com/monaco-io/PulseBar/releases/tag/v1.8.0) is public and Latest, with exactly one uploaded asset, `PulseBar.dmg`. Anonymous download returned HTTP 200. Its 2,503,232-byte payload matches GitHub's digest: `dd0550643177e48502c85c1f6c50ae00a08654b9db6850ef251d6a56d27e7775`. The mounted image has only the app and Applications shortcut as visible items, and its Finder template matches the source.
- The public Raw update feed returns 1.8.0/build 15 and exactly matches the signed feed on `codex/updates` at commit `580addc`. The feed and DMG signatures passed Sparkle cryptographic verification. English release notes match the committed notes.
- The installed app now comes from the public DMG. Binary SHA-256: `76caab12a27ee41a4af1d49c9f6f6a49a2cc64b7460772139006113b6c785372`. Deep strict signing and three diagnostic samples passed. Saved preferences and all 16 existing event IDs were preserved. Native UI confirmed Refresh 2, the complete overview/settings layout, and the update result “PulseBar 1.8.0 is currently the newest version available.”
- Release preflight also verified two large Finder icons and the native language order Follow system → English → 简体中文. Cancelling the language menu retained the Settings panel. This release check verifies the live feed from the current version; a complete upgrade from 1.7.1 was not repeated. Apple notarization and Intel/macOS 13 hardware testing remain outside this verification.
- Evidence: `artifacts/github-v1.8.0/verification.json`, `public-verification.log`, `install-verification.log`, `official-sample.ndjson`, `release.log`, and the native tool captures. `dist/release/PulseBar.dmg` now matches the public artifact.


## 2026-09-22: single instance and performance checks

Local update installed in both existing Applications locations; not published. All 64 tests, universal build/signature checks, 60 cold/warm launch attempts, crash recovery, and packaged sampling passed. Background queues and CLI sampling now have explicit autorelease boundaries; redundant menu bar drawing and hover statistics were reduced. See [the performance report](PERFORMANCE.md) for measurements, the unchanged system XPC cycles reported by `leaks`, and the limits of the short runtime check.


## v1.8.1: published single-instance and performance fixes

Published on 2026-09-22 from tag `v1.8.1`, commit `e6a357939ad519f833e4f7b05f093c14a9aef7ab`, build `16`.

- [Source CI](https://github.com/monaco-io/PulseBar/actions/runs/35727353934) and [Publish release](https://github.com/monaco-io/PulseBar/actions/runs/35727664752) succeeded. Both passed all 64 tests, universal arm64/x86_64 builds, and packaged sampling. Independent review found no release-blocking defects.
- [PulseBar 1.8.1](https://github.com/monaco-io/PulseBar/releases/tag/v1.8.1) is public and Latest, with exactly one uploaded asset, `PulseBar.dmg`. Anonymous download returned HTTP 200. The 2,518,143-byte payload matches GitHub's asset digest: `dbe586adc042cfbe80bd5e5e4c811137ba59f1f460c0127d2c71fcb20819f91a`.
- The mounted DMG contains only the app and Applications shortcut as visible items. Finder layout matches the source template; app resources, deep strict signing, and both architectures passed verification. Feed and DMG Ed25519 signatures were independently checked using only the app's public key.
- The canonical public Raw feed returns 1.8.1/build 16 and exactly matches the signed feed on `codex/updates` at `f5edfcf0c350a4e407d3b894031122cb89abac11`. Release notes match the committed English Markdown.
- Both `/Applications/PulseBar.app` and `~/Applications/PulseBar.app` were replaced with the public DMG's app. Their binary SHA-256 is `e3e0e7b60739d1f47f91365e0bcb4cf2100cb35eb8b35a9563fd662ebe59a146`; deep strict signing passed. Saved monitoring preferences and all 197 pre-release event IDs were preserved. Local `dist` app, DMG, and feed now match the public release.
- Three official installed-app samples returned no errors. Five additional launches across the installed copies exited successfully while retaining one GUI process. Native launch started the official app, but its accessibility inspection timed out; no successful updater-dialog or complete in-app upgrade interaction is claimed for this release.
- Backups and evidence are under `artifacts/github-v1.8.1/`, including `ci.log`, `release.log`, `public-verification.log`, `verification.json`, `install-verification.json`, and `official-samples.ndjson`. The detailed memory findings and short-test limits remain in [PERFORMANCE.md](PERFORMANCE.md). Apple notarization and Intel/macOS 13 hardware acceptance remain outside this release verification.


## 2026-10-05: v1.9.0 public release verified

Release tag `v1.9.0` resolves to `0de44efec4f31de5ef226076eeb3bc90e1d0cd28`, version `1.9.0`, build `17`.

- [Source CI](https://github.com/monaco-io/PulseBar/actions/runs/37249912216) and [Publish release](https://github.com/monaco-io/PulseBar/actions/runs/37250073690) succeeded for that exact commit. Tests, universal builds, packaged sampling, DMG signing, publication, and signed feed publication all passed.
- [PulseBar 1.9.0](https://github.com/monaco-io/PulseBar/releases/tag/v1.9.0) is public and Latest with one uploaded asset, `PulseBar.dmg`. Anonymous download returned HTTP 200. Its 2,598,385 bytes match GitHub's SHA-256 digest: `86137bebdb5acf1040b48923f47acb6fce64e09257ca4bde59cb83b276ba288f`.
- Independent public-key verification passed for the DMG and update feed. The canonical anonymous Raw feed is byte-for-byte identical to the published signed feed and advertises 1.9.0/build 17. Mounted contents, Finder layout, both architectures, app resources, versions, and deep strict code signing passed.
- Both existing installation locations now contain the public DMG's app. Their executable SHA-256 is `579db2d1109ae55cb71df98ac4db596cd5ae519670b5f8f65bc4a3afda5fc7ac`; strict signing passed. Old copies are backed up, the six checked monitoring preferences are unchanged, and all 13 previous event IDs are preserved.
- Three official installed-app samples returned CPU/GPU/storage temperatures without metric errors. Native inspection and a screenshot of the official running app confirmed those temperature rows, absence of memory/battery temperature rows, and the full overview with charts and navigation.
- Public and installation reports, logs, samples, DMG, feed, and backups are under `artifacts/temperature/`. Intel/macOS 13 hardware acceptance and Apple notarization were not performed.

## 2026-10-05: v1.9.0 temperature release preflight

Local candidate `1.9.0` / build `17`; not yet published at this check.

- All 75 tests passed, including temperature encodings, invalid-value rejection, component aggregation, and generation-specific sensor mappings. The universal arm64/x86_64 release build completed. The task location adds Finder metadata; a clean app copy in `/tmp` passed deep strict code-signature verification and both-architecture checks.
- Three packaged-app diagnostic samples returned no errors and real CPU temperatures of approximately 84.6–88.8 °C, GPU temperatures of 79.2–80.8 °C, and storage temperatures around 36.0 °C. No accepted memory or battery sensor was present on the development M4 iMac; those components were omitted. These are observed readings, not thermal health assessments.
- A 13-second real `SystemMonitor` integration check passed with CPU, memory, disk, network, and Swap samples, plus CPU/GPU/storage temperatures. The isolated event store reported no error.
- Native UI captures verified the complete English overview and Chinese overview with expanded Settings. The original Follow System language, 2-second refresh, and 12-hour history were restored. All saved monitoring preferences matched their prior values, and all 13 original event IDs were retained.
- Evidence is under `artifacts/temperature/`, including `tests.log`, `build.log`, `packaged-samples.ndjson`, `integration.json`, and `local-verification.json`; native UI captures are in the task's tool results. Public CI, the released DMG, and the signed update feed still require verification after publication. Intel and macOS 13 hardware testing were not performed.
