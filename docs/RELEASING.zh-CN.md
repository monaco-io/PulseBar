# 分发与发布

[English](RELEASING.md) | 简体中文

## 发布范围

**PulseBar 主程序及更新只通过 Mac App Store 分发；GitHub 后续只发布可选的 PulseBar 助手插件。** 原 `v*` 主程序自动发布工作流已移除，`scripts/package-release.sh` 会拒绝继续制作 GitHub 主程序版本。CI 验证商店构建和助手，不再上传主程序预览包。

历史主程序发布与 `codex/updates` 的 Sparkle 清单保留兼容，不覆盖、不删除、不随插件更新。助手始终标记为非 Latest，避免旧版主程序的 latest 链接指向插件。

## 主程序

先完成修改、检查与候选构建，把真实最新 UI 给用户确认；确认后再按[App Store 分发说明](APP-STORE.md)准备签名、版本号和上传。Apple 审核与公开上架是后续独立步骤。GitHub 不再发布主程序安装包或新版 Sparkle 清单。

## 助手插件

每个版本使用独立的 `helper-v版本号` tag，Release 只附带一个 **PulseBar-Helper.pkg**。助手应用和服务使用 Developer ID Application 签名；PKG 使用 Developer ID Installer 签名，并完成 Apple 公证与票据装订。

安装包只将助手放入个人 `~/Applications`，无安装脚本、不要求管理员权限，也不会自动启用后台服务。安装器提供中英文说明。主程序设置直接打开固定版本的 PKG 下载地址，不经过 GitHub 发布页；安装后按钮变成“打开助手”，用户再明确启用。

Swift 的 `HelperIdentity.version`、构建脚本内助手版本、PKG 与 tag 必须一致。主程序的 App Store 提交 PKG 不得上传 GitHub。

```sh
./scripts/build-store-distribution.sh
./scripts/package-helper-release.sh
```

正式打包需[商店分发说明](APP-STORE.md)列出的签名与描述文件，另外设置 `DEVELOPER_ID_INSTALLER_IDENTITY` 和 `NOTARY_KEYCHAIN_PROFILE`。私钥和公证凭据仅保留在本地钥匙串或授权的密钥存储中。

用户确认最新 UI、检查通过后才能发布：

```sh
git tag -a helper-v1.0.2 -m 'PulseBar Helper 1.0.2'
git push origin helper-v1.0.2
./scripts/publish-helper-release.sh helper-v1.0.2
```

脚本先核对安装包内容、签名团队、公证、tag 版本和已跟踪源码状态，再建立只有一个安装包的草稿，公开为非 Latest。已有同名发布会停止，不能覆盖旧文件。发布后检查匿名直链下载、资产摘要和公证，再提交包含对应助手链接的主程序。

## 本地检查

```sh
./scripts/build-store-distribution.sh --local
./scripts/package-helper-release.sh --local
python3 scripts/verify-helper-installer.py dist/helper-release/PulseBar-Helper.pkg
```

本地包带有 `LOCAL-ONLY.txt`，发布脚本会拒绝上传。检查包结构不会实际安装插件或注册后台项目，也不代表公开下载或 Apple 审核已通过。
