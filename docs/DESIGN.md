# PulseBar interaction design

## Unreleased: compact overview with native glass

The selected design uses one 452 pt column. Every window fits its measured content, including its header and history controls, capped at 80% of the current screen’s usable height. Expanded events grow the detail window and collapse back to their compact height. Only content above the cap scrolls. Reopening preserves the measured height, and moving a pinned detail between screens reapplies the cap. The overview has no bottom navigation. Hover a hardware row for an independent detail window; click or pin to keep it open and draggable. The detail prefers the right side, switches left near a screen edge, and remains within the visible display. Pinned windows survive overview dismissal. CPU and memory pair native circular gauges with readings and small trends; network pairs two rates with one chart; storage separates free capacity and a native usage bar from physical disk I/O. Detail windows retain real sample inspection, averages, peaks, and units, and CPU/memory include application rankings. Settings is a gear action, and Events is in More.

Use system SF typography and semantic system colors: label/background/separator for structure, blue for CPU and incoming traffic, purple for memory and disk writes, green for outgoing traffic. Pressure colors describe the OS pressure state independently of memory occupancy. Native glass buttons carry explicit actions; native segmented controls select history ranges. Hover previews have a 250 ms entry delay and a 400 ms exit grace period. Action buttons and More use actual AppKit NSButton / NSPopUpButton glass bezels on macOS 26+, with standard rounded controls on earlier systems. AppKit owns highlighting, focus, press/release feedback, and toggle state; there is no custom tint, scale, or Core Animation. Settings uses native GroupBox, labeled fields, Picker, Toggle, and NSStepper; event expansion uses DisclosureGroup. All history plots use Swift Charts. Window appearance and content resizing use AppKit utility-window and frame animation, with animated resizing disabled for Reduce Motion. A single persistent content tree preserves event expansion and editing state. The native scroll view automatically hides scrollers when the document fits and disables unnecessary elastic scrolling.

AppKit `NSGlassEffectView` owns the hosting view through its documented `contentView` property on macOS 26+. A public-class compatibility bridge supports the existing Swift 6.0 toolchain. Earlier systems use `NSVisualEffectView.popover`; the native material itself handles Reduce Transparency and contrast preferences. This is one shared glass surface, with no per-metric glass layers.

Reference study: [Stats](https://mac-stats.com/) and [iStat Menus](https://bjango.com/mac/istatmenus/) informed compact readings and detail hierarchy; [MenuBar Stats](https://www.seense.com/menubarstats/) informed the unified vertical panel; Activity Monitor informed pressure and application rankings. The alternative btop-style full console was reviewed and the compact design was selected. [Apple documents the native glass content container](https://developer.apple.com/documentation/appkit/nsglasseffectview/contentview).

The versioned sections below describe earlier layouts. Current validation is recorded separately in [VALIDATION.md](VALIDATION.md).

## v1.12.0: consistent metric hierarchy and alignment

Version 1.12.0 implements the approved layout proposal using the existing production readings. CPU and memory share the first row, storage and network the second; available GPU and internal-battery groups follow below. At available content widths below 500 pt, the same ordered groups become one scrolling column. Optional groups and individual unavailable readings leave no placeholders.

Every group puts its name at the left and its valid component temperature at the right. Main labels align left and numeric readings align right. Primary percentages use 28 pt monospaced digits, paired I/O rates use 24 pt, supporting values use 13 pt, and labels and history statistics use 11 pt. Units remain next to their values at a quieter size. Counts and time estimates stay integers; percentages, temperatures, rates, and formatted decimal byte quantities retain their established precision. Longer translated labels may wrap instead of forcing smaller type or hiding readings.

The hierarchy is heading, main reading, supporting facts, then history and statistics. CPU user/system and memory app/wired/compressed values use equal supporting columns; pressure and swap use labeled rows. Storage separates startup-volume capacity from physical disk I/O. Disk and network share direction, average, and peak columns, followed by paired session totals. CPU and memory histories share a baseline in the two-column layout, as do disk and network histories. GPU keeps one named utilization row per device, and battery keeps every available charge, power-state, capacity, cycle, and time field. A component temperature does not imply a particular GPU device.

Keep the native SF system type, semantic system palette, established chart colors, and light internal dividers. There is no enclosing hardware-card background or border, no progress bar, and no chart area fill. The four charts retain linked inspection, actual sample values, time context, averages, and peaks.

The overview is 620 pt wide with height `min(660, screen.visibleFrame.height - 24)`. Only the middle content scrolls; the header and bottom navigation remain fixed. Sensor availability does not resize an open panel. Details use a 320 pt side column when the screen accommodates the 941 pt expanded width, otherwise they replace the middle content.

CPU and memory headings and primary values retain their Apps shortcuts. Sampling, sensor validity and absence rules, saved preferences, menu-bar options, local performance events, keyboard navigation, and English Events empty-state wrapping retain their existing behavior. UI and build validation belongs in [VALIDATION.md](VALIDATION.md).

## v1.11.0: hardware groups without the outer frame

Version 1.11.0 refines the overview introduced in v1.10.0, keeping each hardware group readable within a wider, shorter panel.

The overview retains internal CPU, memory, GPU, storage, network, and battery groups, hierarchy, and horizontal and vertical dividers. CPU and optional GPU occupy the upper left, memory and optional internal battery the upper right, with storage and network below. Only the `RoundedRectangle` background and `strokeBorder` surrounding all of `hardwareContent` are removed; its transparent `VStack` sits directly in the native panel. All existing usable readings remain available, with optional groups omitted without reserved slots. GPU utilization names each reported device, while component temperatures remain in their own hardware headings and do not imply a particular GPU device.

There are no progress views, occupancy bars, or other filled gauges. Utilization, charge, and capacity appear as numbers with labels; pressure and power state appear as text. The four established CPU, memory, physical-disk, and network histories remain pure line charts without area fills. Preserve their linked inspection and time context.

Use the native SF system type, monospaced digits, material, and semantic system palette. Retain the internal typography: 22 pt primary values, 20 pt rates, and 11 pt body labels and statistics. Compact layout must not depend on reducing that text. Retain the existing CPU orange, memory purple, GPU teal, incoming blue, and outgoing green accents.

The overview is 560 pt wide, with height `min(660, screen.visibleFrame.height - 24)`. Available content widths below 500 pt use a single scrolling column. Aim to keep all readings readable in one panel on common screens, while retaining a scrolling middle-content fallback for short screens, longer translated labels, and extra available hardware. The header and bottom navigation stay fixed. Optional sensor availability does not resize an open panel. Details retain the 320 pt side column when the screen can accommodate the 881 pt expanded width; otherwise they replace the middle content.

CPU and memory headings and usage values retain their Apps shortcuts. Sampling cadence, reader validity rules, absence behavior, saved settings, menu-bar options, linked history inspection, and local performance-event behavior remain unchanged. English Events empty-state text wrapping is preserved. Validation evidence and the limits of the hardware and UI checks are recorded in [VALIDATION.md](VALIDATION.md).

## Released v1.10.0: hardware modules

The overview groups readings by hardware while preserving the established app, event, and settings navigation.

The overview follows hardware boundaries: CPU, memory, GPU, storage, network, and the Mac's internal battery. Readings belong to their module, with a valid component temperature on the right of its heading. A missing temperature leaves no empty placeholder. Optional GPU and battery sections disappear when they have no usable data; a battery temperature alone cannot create a host-battery section on a desktop.

| Module | Headline and supporting readings |
| --- | --- |
| CPU | Whole-Mac utilization; user/system split; logical-core count; existing usage history; optional temperature. Heading and utilization remain Apps shortcuts. |
| Memory | Used/total and utilization; app, wired, and physical compressed memory; pressure and swap; existing usage history; optional temperature. Heading and utilization remain Apps shortcuts. |
| GPU | One named row per driver-reported device utilization; optional component temperature in the heading. Percentages are not combined and the temperature is not assigned to a particular GPU row. |
| Storage | Startup-volume used/total, ordinary available space, and usage bar; separately labeled physical-device read/write rates, history, and session totals; optional temperature. |
| Network | Download/upload rates, linked history, session traffic, and active interface names. |
| Internal battery | Available charge, charging/full/battery/external-power state, retained maximum capacity, cycle count, official time estimate, and optional temperature. Requires one present internal host battery. |

Use the existing native material, semantic colors, SF type, monospaced digits, and divider hierarchy. CPU remains orange, memory purple, incoming traffic blue, and outgoing traffic green; GPU uses system teal. Keep secondary facts quieter than live percentages and paired I/O rates. Capacity describes startup-volume space, while throughput explicitly describes physical disk I/O.

The overview stays 400 pt wide. Its height is `min(820, screen.visibleFrame.height - 24)`; sensor availability does not resize an open panel. Only the middle content scrolls, with the header and Overview/Apps/Events/Settings navigation fixed. The four established history charts remain available within their modules, without requiring all four to fit on screen at once. Details retain the same 320 pt side column, or replace the middle content on narrow screens.

CPU and memory headings and values open the matching Apps tab. Preserve linked chart inspection, keyboard/Escape navigation, Settings behavior, four menu-bar metric choices, saved preferences, and local performance events. New modules do not create additional menu-bar choices, historical series, or event categories.

Optional reads run on background serial queues with at most one request in flight per queue. GPU/temperature sampling uses a minimum of 5 seconds and startup-volume/battery sampling a minimum of 30 seconds, each respecting longer Refresh settings. Stop, Reset, sleep/wake, and stale callback rejection clear optional values. A failed scheduled read replaces a previous value with absence rather than displaying stale data.

See [hardware modules](HARDWARE-MODULES.md) for data sources, units, absence rules, and validation limits.

## Previous design: v1.8 stable navigation and restrained motion

The panel is a compact instrument for reading live system activity. Preserve the four-chart overview while making app detail, events, and preferences easy to find.

### Visual tokens

- Native popover material: light reference `#F5F5F7`, dark reference `#242426`.
- Primary label: dynamic system label, light reference `#1D1D1F`.
- CPU `#FF9500`, memory `#AF52DE`, incoming traffic `#007AFF`, outgoing traffic `#248A3D`; use their adaptive system-color equivalents.
- SF system type: 16 pt title, 24–25 pt rounded live values with monospaced digits, 11–12 pt controls, 9–10 pt chart context.
- Overview width 400 pt; one 320 pt detail column for every destination. Main labels align left and values align right. Show one detail destination at a time.

### Navigation

```text
PulseBar                   Live status   More
CPU details        Memory details       | Apps / Events / Settings   Close
CPU + memory charts                      | CPU / Memory selector
Pressure and swap                        | Detail content
Disk reads / writes and chart            |
Network down / up and chart              |
Overview     Apps     Events     Settings |
```

- The bottom navigation is persistent. Selecting an already active destination keeps it open. Overview and the detail close button return to the compact monitor.
- CPU and memory readings are shortcuts to the corresponding Apps tab. Switching between Apps, Events, and Settings keeps the same window size.
- Settings groups: menu bar display; sampling and language; startup and notifications; software updates. The update section no longer pushes everyday controls down the page.
- New installations refresh every 2 seconds. Preserve saved intervals. Language choices appear as Follow System, English, then 简体中文.
- More and right-click menus provide navigation, update checks, Reset, and Quit. Opening or selecting native menus must not dismiss the panel as an outside click.
- On displays too narrow for the detail column, details replace the middle content while the header and bottom navigation stay available.

### Motion and stability

- A single route value replaces competing settings/insight flags. Window geometry is committed from the new route once per navigation change.
- Keep the window and hosting controller alive; commit window geometry without AppKit frame interpolation. Align content to the leading edge and use one width for every detail destination.
- Use a short ease-out opening, a quiet detail reveal, and subtle hover/pressed feedback. Window width changes atomically so AppKit and SwiftUI never animate competing layouts. Live samples do not animate the entire panel. Respect Reduce Motion and Reduce Transparency.
- Escape closes a native menu first; otherwise it returns from details to Overview, then dismisses the panel. Clicking outside dismisses the panel.

### Design review

Four identical metric cards would obscure the relationships between percentages and paired I/O rates. Keep the existing instrument-like chart hierarchy; spend the visual emphasis on a clear selected navigation item and direct metric shortcuts. Avoid continuous pulsing and decorative entrance animations on every row.

## Earlier design notes

# 系统监控组件的界面方向

## v1.5：折叠设置与登录启动

- 主面板专注监控读数与曲线；四项显示开关、语言、刷新频率、取样范围和开机启动统一放在“设置”侧栏中，默认折叠，每次重新打开面板也收起。重置和退出保留在底部设置按钮同一行。
- 移除滚动容器，监控区固定 400 pt 宽，四类数据和曲线同时完整展示。设置在右侧增加 260 pt 侧栏及 1 pt 分隔线，不挤压监控区高度；侧栏以双列显示四项菜单栏开关，其余设置逐行对齐。最后一项开关保护和输入框结束编辑时释放焦点的行为保留。
- 开机启动使用 SMAppService.mainApp 注册当前用户的登录项，首次运行不自动注册；以系统状态为准。等待系统允许时明确提示尚未生效，提供系统登录项入口；失败时保留实际开关状态并展示原因。

## v1.4.1：汇总单位与输入焦点

- 内存用量和本次磁盘 / 网络累计根据大小自动采用 B、KB、MB、GB、TB 等十进制单位，统一一位小数；内存已用 / 总容量使用同一单位。接近单位边界时按显示精度晋级，避免出现 `1000.0 MB`。实时速率继续使用 MB/s。
- 输入框只在用户编辑时显示焦点；Return、点击其他区域或关闭面板时结束编辑并保存，重新打开面板不自动选中设置。保留原生编辑焦点和键盘导航。

## v1.4：小时输入与完整网络曲线

- History 使用 hour / 小时，支持 `0.5`、`1`、`2` 等输入，最多 24 小时。新安装默认 1 小时；旧取样时长按原值换算，配置字段最多四位小数，以便旧的秒数设置可准确还原。实时读数仍统一一位小数。
- 删除默认重复的开关说明，仅在剩一项时保留提示。缩小区块间距，CPU / 内存曲线高 24 pt，磁盘 / 网络曲线高 36 pt；保持 400 × 560 pt 的面板，让网络双向折线默认可见。较矮屏幕和错误提示仍可通过中间区域滚动查看。
- 最多保留 24 小时原始采样；绘制时按图表宽度选取每个区间的双向极值，限制顶点数并保留峰值。

## v1.3：脉动 · PulseBar

- 应用文件和英文界面使用 PulseBar，简体中文使用“脉动”。沿用旧版应用标识和菜单栏位置标识，更新时继续读取已保存的开关、语言和刷新配置。
- 取样范围与刷新间隔独立。底部第二行提供取样范围输入和步进器，单位为秒，支持 1–3600 秒；300 秒对应最近 5 分钟，默认 60 秒。CPU、内存、磁盘和网络同步切换时间尺度，图表轴和辅助功能说明使用对应的秒、分钟或小时。
- 本次运行保留最近 1 小时的采样，扩大范围可以显示已有历史。窗口边界插值后再确定吞吐量坐标上限，避免不可见的旧峰值压低当前曲线；未采集时段保持空白。
- 所有读数统一一位小数。容量固定 MB、速率固定 MB/s，微小非零值显示小于 0.1。菜单栏为常见数值预留宽度，遇到更长的数字自动扩展，单项显示和全部显示使用同一套布局。

## v1.2.0：显示、语言和刷新设置

- CPU、内存、磁盘和网络标题各有原生小号开关，只控制菜单栏展示。菜单栏宽度根据选中项自动收缩；CPU 和内存只剩一项时读数垂直居中。保留至少一项，最后一个开关禁用，顶部提示切换为对应说明。
- 标题、提示和底部设置固定可见。底部第一行是语言菜单和刷新秒数输入 / 步进按钮，第二行是时间范围、重置和退出。沿用 400 pt 宽、最多 560 pt 高，中间监控区域可滚动。
- 界面支持简体中文、English 和跟随系统；文字、菜单栏提示、错误信息与辅助功能描述一起切换。英文标题、较长的内存容量和低速率文本需在真实 App 中检查。
- 速率固定 MB/s，容量及累计固定 MB；不再提供单位切换。CPU 和内存百分比保留。刷新 1–60 秒，默认 1 秒；长刷新间隔仍用实际经过时间计算，图表保持最近 60 秒的时间尺度。

## v1.1.0 历史设计

## CPU、内存与磁盘 I/O 扩展

继续以原生读数工具为定位：菜单栏用三组双行数字显示 CPU / MEM、磁盘 R / W、网络 ↓ / ↑；弹出面板在同一屏内查看四类监控。

- 配色沿用动态系统色：背景浅色 #F5F5F7 / 深色 #242426，主文字 #1D1D1F，网络下载 #007AFF、上传 #248A3D；CPU 用 systemOrange（浅色 #FF9500）、内存和磁盘写入用 systemPurple（浅色 #AF52DE）。颜色都通过系统语义色实现。
- 保留 SF 系统字体与等宽数字。CPU、内存使用 25 pt 百分比，读写和网速使用 24 pt 数值，说明为 10–11 pt。
- 400 pt 宽、20 pt 横向内边距；CPU 和内存并排，磁盘和网络纵向排列。面板高度不超过 560 pt，并按当前屏幕可用高度减去 24 pt 限制；标题与底部操作固定，中间内容可滚动，适配较矮或缩放后的屏幕。用留白和分隔线表达不同统计范围，不加入装饰卡片。每类保留 60 秒曲线；百分比固定 0–100，吞吐量动态缩放。
- CPU 明确为整机占用；内存显示已用 / 总量；磁盘明确读 / 写和物理设备。网络单位切换只影响网络。首次采样和失败显示破折号，错误局部提示且自动重试。

```
[系统图标] 系统监控              ● 每秒更新
CPU                   内存
24.8%                 67.2%
用户 / 系统            已用 / 总量
小曲线                 小曲线
──────────────────────────────────────
磁盘 I/O                       3 个磁盘
读取                   写入
23.4 MB/s              4.2 MB/s
最近 60 秒双向曲线
──────────────────────────────────────
网络                       [B/s | b/s]
下载                   上传
12.4 MB/s              840 KB/s
最近 60 秒双向曲线
累计 / 活动网卡
──────────────────────────────────────
最近 60 秒                      重置 退出
```

评审：四类指标需要明确读数和时间尺度，原有系统字体、分隔线和单一面板符合这个用途；两项占用率并排、两项吞吐量各自共享尺度，减少眼睛在标签和曲线间来回查找。

## 原始网速面板

用途是随时扫一眼网速，点击后判断最近的流量变化。采用原生菜单栏和瞬时弹出面板；数字优先，不增加装饰性卡片或仪表盘。

- 配色：窗口原生动态背景（浅色约 #F5F5F7 / 深色约 #242426）；文字使用系统 label；次要文字使用 secondaryLabel；下载为 systemBlue（浅色 #007AFF），上传为 systemGreen（浅色 #248A3D）。深色模式使用系统对应颜色。
- 字体：SF 系统字体；主要速率 29 pt、圆角数字；菜单栏 9.5 pt 等宽数字；正文 11–12 pt。不加载网络字体。
- 布局：364 pt 宽、22 pt 内边距；标题与状态、两列速率、一张共享尺度的 60 秒曲线、累计和网卡、底部操作。内容左对齐，统计值右对齐。
- 交互：整块菜单栏读数可点击；面板点击外部关闭；无持续动画；颜色同时配箭头和文字；底部提供单位、重置、退出。

```
[网络图标] 网速                       ● 正在监测
↓ 下载                       ↑ 上传
12.4 MB/s                    840 KB/s
最近 60 秒                           上限
┌────────── 两条流量曲线 ──────────────┐
60 秒前                              现在
本次累计                    ↓ ...  ↑ ...
活动网卡                        Wi-Fi (en0)
[单位] 每秒更新                  重置  退出
```

评审：这是 macOS 的轻量读数工具，速度数字和曲线是必要的信息主体。用单一面板和共享曲线替代重复卡片，使用系统语义颜色保证外观适配，避免与菜单栏工具无关的网页视觉元素。
