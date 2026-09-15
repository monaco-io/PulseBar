# 脉动 · PulseBar

[English](README.md) | 简体中文

原生 macOS 菜单栏组件，实时显示 CPU、内存、磁盘 I/O 和下载 / 上传速度。支持应用资源排行、内存压力和 Swap、曲线联动查看，以及带应用快照的异常事件时间线。

## 下载安装

**[下载最新版 DMG](https://github.com/monaco-io/PulseBar/releases/latest/download/PulseBar.dmg)** · [版本说明](https://github.com/monaco-io/PulseBar/releases/latest)

支持 **macOS 13+，Apple Silicon 和 Intel**。打开 DMG，把 PulseBar 拖入 Applications，再从应用程序目录启动。当前版本采用 ad-hoc 签名，尚无 Apple Developer ID 公证；若系统阻止打开，确认来源后在“系统设置 → 隐私与安全性”中选择“仍要打开”。详见[安装说明](docs/INSTALL.zh-CN.txt)。

### 软件更新

点击菜单栏读数 → **设置 → 软件更新**，可查看当前版本、手动检查更新、开关每日自动检查或打开下载页。自动检查发现新版后，“设置”旁显示下载提示；由你选择下载、安装并重启，设置与本地事件历史保留。1.7.0 及更早版本需要先手动安装 1.7.1 一次，迁移到新的更新地址。

更新使用 [Sparkle](https://sparkle-project.org/)，从独立地址读取更新清单，下载 GitHub Release 中的同一个 DMG；清单与 DMG 均使用 Ed25519 签名验证，关闭系统信息上报。更新检查会访问 GitHub；监控数据与事件历史保留在本机。

## 使用

底部使用“总览 / 应用 / 事件 / 设置”统一导航，应用页内切换 CPU / 内存。详情栏宽度一致，窄屏时在面板内展示详情。顶部“更多”菜单收纳更新、重置和退出；右击菜单栏读数也可快速操作。Escape 先返回总览，再关闭面板；Command-1 至 Command-4 切换主要页面。动画遵循系统“减少动态效果”。

需要 macOS 13 或更新版本。双击 `PulseBar.app`，读数出现在屏幕顶部菜单栏，不占用 Dock 图标。

- 菜单栏从左到右为 `CPU / MEM` 使用率、磁盘 `R / W` 读取 / 写入速率、网络 `↓ / ↑` 下载 / 上传速率。默认每 2 秒更新，可配置为 1–60 秒。
- “设置 → 菜单栏显示”分别控制 CPU、内存、磁盘和网速是否在菜单栏显示，修改后立即生效并保存。至少保留一项，最后一项的开关会禁用；隐藏后面板中的数据仍继续采样和显示。
- 点击读数打开面板；点击外部或按 Escape 关闭。
- 面板固定展示 CPU、内存、磁盘和网络数据与完整折线图，不使用滚动区域；网络下载为蓝线、上传为绿线。设置在右侧展开，不压缩或遮挡监控内容；标题与底部导航始终可见。
- 网络和磁盘速率固定为 MB/s；内存容量、流量与磁盘累计按大小自动显示 B、KB、MB、GB、TB 等单位。采用十进制换算，1 GB = 1000 MB；内存已用 / 总量使用相同单位，例如 `21.3 / 25.8 GB`。读数统一保留一位小数，微小非零速率显示 `<0.1 MB/s`。
- 内存显示使用率和已用 / 总容量；鼠标悬停可查看应用、联动和压缩内存。CPU 与内存占比仍使用百分比。
- 点击面板中 CPU 或内存的标题 / 大号读数，在右侧查看占用最高的 5 个应用。辅助及子进程按所属应用合并，可直接打开活动监视器；切换排行不停止采样。主面板扩展到最高 640 pt，保留四图总览；排行、事件与设置侧栏一次只显示一个，较长的详情可滚动。
- 内存压力显示 macOS 返回的正常、偏高或紧张状态；Swap 显示交换空间用量与所选范围内的变化量。内存侧栏提供 Swap 趋势图。读取失败显示 `—`，不会通过内存占用百分比推断压力。
- 鼠标悬停任一主图，四张图同步显示时间游标，各图下方显示该实际样本的读数，顶部显示准确到秒的时间；大号数字继续实时更新。查看期间图表时间范围固定，移开鼠标恢复滚动更新。尚未采集或已中断的时段显示“此时尚无采样”。平时图下显示所选范围的时间加权均值及峰值，未采集时间不参与计算。
- 底部“事件”打开异常时间线：CPU ≥ 85% 持续 30 秒，或内存压力偏高 / 紧张持续 10 秒时记录事件，保存触发时的 CPU、Swap、压力和 CPU / 内存前五名快照。展开事件查看当时的应用；快照表示同时发生的状态，不表示已确认的原因。每段持续状态只记录一次，恢复或压力等级变化后重新观察；读取中断及休眠重置持续时长。
- 事件仅在本机保留最近 7 天、最多 200 条，退出 / 重启应用后仍可查看。设置中的“事件通知”默认关闭，只在主动开启时申请系统授权；每种事件独立应用 1–60 分钟冷却，默认 10 分钟。通知关闭或未授权仍记录事件，开启后仅通知新事件。清空事件需在事件侧栏确认，普通“重置”保留事件历史。
- 底部“设置”默认折叠，每次打开面板都从折叠状态开始。点击后在侧栏调整菜单栏显示、语言、刷新、曲线范围和开机启动；重置与退出位于顶部更多菜单。
- 设置中的语言菜单支持跟随系统、简体中文和 English，界面、说明、错误提示及辅助功能标签即时切换，无需重启；未支持的系统语言回退到 English。
- 设置中的“刷新”可输入 1–60 的秒数后按 Return，或使用步进按钮调整；立即重设采样计时器并保存。无效输入恢复原值，超出范围会限制到 1–60 秒。
- 设置输入框只在编辑时显示焦点；按 Return 或点击其他区域保存并退出编辑，重新打开面板时不会保持选中。
- 设置中的“取样范围 / History”按小时输入，单位为“小时 / hour”，支持小数，例如 `0.5` 为 30 分钟、`2` 为 2 小时，最多 24 小时；上下按钮每次调整 0.5 小时。新安装默认 1 小时，旧设置保留原时长（例如 5 分钟显示为 `0.0833 hour`）。输入后按 Return，四类曲线和时间刻度同步变化，不改变刷新间隔。程序最多保留本次运行最近 24 小时的数据，扩大范围会复用已有采样；启动前或读取中断的数据不补造，退出后曲线清空。
- “开机启动 / Launch at login”控制登录当前 Mac 账户时自动打开应用，通过 macOS [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp) 管理。首次运行不自动开启；开关读取系统实际状态，若需系统允许，会显示提示及“打开登录项设置”入口。可随时关闭；从系统设置返回后自动同步状态。
- “重置”清空所有曲线、本次网络流量和磁盘读写累计；“退出”结束程序。
- CPU 和磁盘首次采样先建立基线，一个刷新周期后开始显示。个别指标读取失败时显示 `—` 并自动重试，其他监控继续更新。
- 如果菜单栏空间不足，可关闭其他菜单栏项目或按住 Command 拖动读数调整位置。

## 构建和运行

监控功能使用系统框架，软件更新使用 Sparkle 2.10.0。安装 Xcode Command Line Tools（`xcode-select --install`），Swift 6.0 或更新版本即可构建。首次构建从 Sparkle 官方 Release 下载固定版本的二进制依赖，SwiftPM 校验其 SHA-256。

```sh
./scripts/build-app.sh
open dist/PulseBar.app
```

构建脚本分别编译 arm64 / x86_64，再合并为通用 `dist/PulseBar.app` 和 `dist/PulseBar.zip`，默认做本地 ad-hoc 签名。可将其复制到 `~/Applications` 长期使用，再按需开启开机启动。Sparkle 框架及全部资源随 App 打包，不依赖开发目录。正式发布与可选 Developer ID 签名、公证步骤见[发布说明](docs/RELEASING.zh-CN.md)。

```sh
./scripts/swift-local.sh test --disable-xctest
.build/release/PulseBar --sample 5
.build/release/PulseBar --sample 3 --interval 6
```

采样命令输出 NDJSON，包括原有网卡计数和速率字段，以及 `cpu`、`memory`、`disk`、`memoryPressure`（1 正常 / 2 偏高 / 4 紧张）、`swap`、`apps`（前五名排行、已采样与不可读取进程数）。诊断原始数据仍以字节和字节每秒计量，界面速率换算为 MB/s，容量及累计自动选择单位。首次 CPU 和磁盘速率为 `null`，应用 CPU 排行等待基线。`--interval` 指定诊断采样秒数，默认 1，不修改 App 设置；诊断路径不记录事件、不发送通知。各指标独立读取；失败写入 `errors`，继续采样其他指标，最终返回非零退出码。不会启动额外界面。

构建入口兼容部分 Command Line Tools 升级后残留的重复 `SwiftBridging` 模块定义和旧 `PackageDescription` 私有接口。兼容文件仅生成在项目 `.build` 中，不修改系统工具链。正常工具链也可以直接执行 `swift build` 和 `swift test`。

## 统计范围

### 应用排行、内存压力和事件

通过 `proc_listallpids`、`proc_pidinfo`、`proc_pidpath` 和 `proc_pid_rusage` 读取当前可访问进程的身份及计数，不读取命令行参数或进程内容。CPU 累计值先按 `mach_timebase_info` 从 Mach tick 转为纳秒，再按实际经过时间及逻辑核心数归一化为整机 0–100%，不采用活动监视器的“单核心 100%”口径。首次采样、新进程、PID 复用、计数回退或采样中断均重新建立基线。内存采用 `ri_phys_footprint`；与系统已用内存统计范围不同，不能直接相加对账。

可执行路径中的最外层 `.app` 标识应用；没有自身应用路径的子进程沿父进程链归属。无法找到所属应用的服务按可执行路径单列，不能把所有由 launchd 托管的 XPC 服务可靠地归到调用应用。已退出或权限限制导致无法读取的进程会被跳过，面板显示统计覆盖数量；不申请管理员权限。进程采样和事件落盘使用独立串行后台队列。

压力读取 `kern.memorystatus_vm_pressure_level`，其返回值是用户空间压力标志，见 [Apple XNU 实现](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_memorystatus_notify.c)。Swap 读取 `vm.swapusage`。压力与内存占用率互相独立，含义参考 [Apple 内存说明](https://support.apple.com/en-gb/guide/activity-monitor/actmntr1004/mac)。

事件按采样覆盖的持续时间判定，较长刷新间隔会推迟检测；两个样本之间发生并恢复的状态可能无法观察到。事件存于 `~/Library/Application Support/PulseBar/events.json`，采用原子写入，记录时间、指标和排行，不上传。通知使用系统 UserNotifications，仅在用户主动开启时请求授权。

### CPU 和内存

CPU 使用 Mach `host_statistics(HOST_CPU_LOAD_INFO)` 的用户、系统、空闲和 nice 累计 tick 差值计算，所有逻辑核心合计归一化为 0–100%，不是启动以来的平均值。CPU 曲线和内存曲线固定为 0–100%。

内存使用 [`host_statistics64`](https://developer.apple.com/documentation/kernel/1502863-host_statistics64) 的 `HOST_VM_INFO64` 和本机页大小：已用 = 应用（anonymous/internal 页扣除 purgeable 页）+ 联动（wired）+ 压缩数据实际占用页。不把文件缓存算作已用，也不把压缩前大小重复相加；占用百分比不等同于内存压力。分类含义参考 [Apple 活动监视器说明](https://support.apple.com/guide/activity-monitor/view-memory-usage-actmntr1004/mac)。

### 磁盘 I/O

通过 IOKit 枚举 `IOBlockStorageDriver`，读取 [`Statistics` 的 `Bytes (Read)` / `Bytes (Write)`](https://github.com/apple-oss-distributions/IOStorageFamily/blob/main/IOBlockStorageDriver.h) 64 位计数，按实际采样间隔计算物理设备读写速率。合计内置和外接磁盘，不叠加 APFS 卷 / 分区；排除报告为 `Virtual Interface` 的设备。这里监测磁盘传输，不是磁盘空间占用或仅某个进程的文件操作；命中文件缓存的读取不一定产生物理 I/O。

各磁盘通过 IORegistry ID 独立建立基线，重新接入或 BSD 名称复用时不把历史字节数计入当前速率。磁盘曲线独立缩放，磁盘和网络显示单位均固定为 MB/s。

### 网络

读取 macOS 内核 `NET_RT_IFLIST2` 的 64 位收发计数，按配置的间隔采样并根据实际经过时间计算速率。合计处于 UP/RUNNING 状态的 `en<N>` 网卡（Wi-Fi、有线、常见 USB 网络适配器），并通过 SystemConfiguration 排除已知未连接的网口。包括局域网流量和协议开销。

不重复累加 `utun`、回环、网桥和 AirDrop 虚拟接口；VPN 的实际传输仍由底层物理网卡计入。不会捕获数据包、读取访问内容、发送遥测、主动测速或要求管理员权限。

所有采样都在进程内调用系统接口，不启动周期性子进程。网络流量和磁盘读写的“本次累计”从启动或重置开始，退出后清零。切换设备、计数器重置、休眠唤醒或采样中断超过允许阈值时重新建立基线，避免虚假峰值；基线间隔不计入累计。阈值随刷新间隔调整，较长的正常采样不会被误判成停顿；更改刷新间隔保留累计。CPU 和磁盘采样异常同样会丢弃旧基线；内存恢复后直接显示最新值。保留最近 24 小时及其边界前的一个采样点；显示时按所选时间范围裁剪和插值，使较长刷新周期下仍可正确绘制窗口边界。较长曲线根据绘图宽度选取双向极值，保留峰值并限制实际绘制的点数。

## 多语言资源

翻译位于 `Sources/SpeedCore/Resources/{en,zh-Hans}.lproj/Localizable.strings`，应用名称的系统语言翻译位于 `Resources/*.lproj/InfoPlist.strings`，采用 [Swift Package 本地化资源](https://developer.apple.com/documentation/xcode/localizing-package-resources)。构建脚本将资源包复制到 App 内，分发后的应用不依赖开发目录。设置通过 UserDefaults 保存，键为 `menuBarMetrics`、`appLanguage`、`refreshSeconds` 和 `historySeconds`。从原 NetSpeed 更新时沿用应用标识，保留既有设置和菜单栏位置。

实现由 AppKit 的 [NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem) / [NSPopover](https://developer.apple.com/documentation/appkit/nspopover) 承载 SwiftUI 面板。内核数据结构以本机 SDK 的 `net/if.h` 和 `net/if_var.h` 为准。
