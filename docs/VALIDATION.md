# 本机验证记录

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
