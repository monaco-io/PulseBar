# PulseBar Helper 1.0.1

- 启用和停用助手时保持界面响应，显示操作进度；需要允许后台项目时可直接打开登录项设置。
- 新增“打开 PulseBar”按钮，明确启用后的下一步。
- 使用新的后台服务注册，避免沿用失效的旧注册；保留原有本地认证连接，兼容当前商店版。
- 重连客户端共用采样器和缓存，提取进程名称时避免多余的文件系统检查。

可选助手为 Mac App Store 版 PulseBar 提供应用占用排行及设备支持的硬件温度。需要 macOS 13 或更新版本，支持 Apple Silicon 和 Intel，仅在当前用户下运行，监控数据不会通过网络发送。

助手应用及磁盘映像均使用 Developer ID 签名，经过 Apple 公证并装订公证票据。下载 **PulseBar-Helper.dmg**。更新前打开旧助手，点击“停用助手”后退出；替换 Applications 中的 **PulseBar Helper.app**，打开新版并启用。按系统提示允许后台项目，再点击“打开 PulseBar”。

[安装与排查](https://github.com/monaco-io/PulseBar/blob/helper-v1.0.1/docs/HELPER.md) · [隐私说明](https://github.com/monaco-io/PulseBar/blob/helper-v1.0.1/docs/PRIVACY.md) · [English](https://github.com/monaco-io/PulseBar/blob/helper-v1.0.1/docs/releases/helper-v1.0.1.md)
