# 脉动 · PulseBar

原生 macOS 菜单栏组件，实时显示 CPU、内存、磁盘 I/O 和下载 / 上传速度。点击读数查看可自定义时间范围的曲线、内存用量、本次磁盘读写与网络流量累计。

## 使用

需要 macOS 13 或更新版本。双击 `PulseBar.app`，读数出现在屏幕顶部菜单栏，不占用 Dock 图标。

- 菜单栏从左到右为 `CPU / MEM` 使用率、磁盘 `R / W` 读取 / 写入速率、网络 `↓ / ↑` 下载 / 上传速率。默认每秒更新，可配置为 1–60 秒。
- 各指标标题旁的开关分别控制 CPU、内存、磁盘和网速是否在菜单栏显示，修改后立即生效并保存。至少保留一项，最后一项的开关会禁用；隐藏后面板中的数据仍继续采样和显示。
- 点击读数打开面板；点击外部或按 Escape 关闭。
- 默认面板同时展示 CPU、内存、磁盘和网络折线图；网络下载为蓝线、上传为绿线。面板会适配屏幕可用高度，较矮的屏幕可滚动查看内容；标题、设置、重置和退出始终可见。
- 网络和磁盘速率固定为 MB/s；内存容量、流量与磁盘累计按大小自动显示 B、KB、MB、GB、TB 等单位。采用十进制换算，1 GB = 1000 MB；内存已用 / 总量使用相同单位，例如 `21.3 / 25.8 GB`。读数统一保留一位小数，微小非零速率显示 `<0.1 MB/s`。
- 内存显示使用率和已用 / 总容量；鼠标悬停可查看应用、联动和压缩内存。CPU 与内存占比仍使用百分比。
- 底部语言菜单支持跟随系统、简体中文和 English，界面、说明、错误提示及辅助功能标签即时切换，无需重启；未支持的系统语言回退到 English。
- 底部“刷新”可输入 1–60 的秒数后按 Return，或使用步进按钮调整；立即重设采样计时器并保存。无效输入恢复原值，超出范围会限制到 1–60 秒。
- 设置输入框只在编辑时显示焦点；按 Return 或点击其他区域保存并退出编辑，重新打开面板时不会保持选中。
- 底部“取样范围 / History”按小时输入，单位为“小时 / hour”，支持小数，例如 `0.5` 为 30 分钟、`2` 为 2 小时，最多 24 小时；上下按钮每次调整 0.5 小时。新安装默认 1 小时，旧设置保留原时长（例如 5 分钟显示为 `0.0833 hour`）。输入后按 Return，四类曲线和时间刻度同步变化，不改变刷新间隔。程序最多保留本次运行最近 24 小时的数据，扩大范围会复用已有采样；启动前或读取中断的数据不补造，退出后曲线清空。
- “重置”清空所有曲线、本次网络流量和磁盘读写累计；“退出”结束程序。
- CPU 和磁盘首次采样先建立基线，一个刷新周期后开始显示。个别指标读取失败时显示 `—` 并自动重试，其他监控继续更新。
- 如果菜单栏空间不足，可关闭其他菜单栏项目或按住 Command 拖动读数调整位置。

## 构建和运行

仅使用系统框架，无第三方依赖。安装 Xcode Command Line Tools（`xcode-select --install`），Swift 6.0 或更新版本即可构建。

```sh
./scripts/build-app.sh
open dist/PulseBar.app
```

构建脚本生成当前 Mac 架构的 `dist/PulseBar.app` 并做本地 ad-hoc 签名。可将其复制到 `~/Applications` 长期使用；不自动添加登录项。不包含 Developer ID 签名或公证，面向本机使用。

```sh
./scripts/swift-local.sh test --disable-xctest
.build/release/PulseBar --sample 5
.build/release/PulseBar --sample 3 --interval 6
```

采样命令输出 NDJSON，保留原有网卡计数和速率字段，并增加 `cpu`（使用率）、`memory`（已用 / 总量及分类字节数）、`disk`（读写速率、累计和物理设备计数）。诊断原始数据仍以字节和字节每秒计量，界面速率换算为 MB/s，容量及累计自动选择单位。首次 CPU 和磁盘速率为 `null`，表示等待基线。`--interval` 指定诊断采样秒数，默认 1，不修改 App 设置。各指标独立读取；失败写入 `errors`，继续采样其他指标，最终返回非零退出码。不会启动额外界面。

构建入口兼容部分 Command Line Tools 升级后残留的重复 `SwiftBridging` 模块定义和旧 `PackageDescription` 私有接口。兼容文件仅生成在项目 `.build` 中，不修改系统工具链。正常工具链也可以直接执行 `swift build` 和 `swift test`。

## 统计范围

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
