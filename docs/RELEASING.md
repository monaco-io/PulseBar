# GitHub 发布与更新

## 发布布局

**Release 只上传 `PulseBar.dmg`。** 安装和自动更新共用同一个签名 DMG。安装说明随 DMG 分发，版本说明放在发布正文；不再上传 ZIP、独立说明或校验文本。GitHub 页面会显示资产的 SHA-256，并自动附带两个源码下载链接，它们不是手动上传的附件。

签名更新清单单独保存在 `codex/updates` 分支：
<https://raw.githubusercontent.com/monaco-io/PulseBar/codex/updates/appcast.xml>

App 内的 `SUFeedURL` 固定指向此地址；feed 内的 DMG 链接指向具体版本 tag。`1.7.0` 的旧更新地址在 Release 附件中，精简后不再提供；这版及更早的用户需手动安装 1.7.1 一次。

## 日常发布

1. 同时提高 `Resources/Info.plist` 中的 `CFBundleShortVersionString` 和 `CFBundleVersion`。
2. 添加 `docs/releases/v版本号.md`，提交代码并确认 CI 成功。
3. 创建并推送对应 tag，例如：

   ```sh
   git tag -a v1.7.2 -m 'PulseBar 1.7.2'
   git push origin v1.7.2
   ```

**Publish release** 核对递增版本，运行测试，编译双架构 App 并诊断采样。打包脚本生成 `dist/release/PulseBar.dmg` 和 `dist/updates/appcast.xml`；验证 DMG 挂载、资源、系统要求、版本及数字签名。先上传 DMG 为草稿并公开为 Latest，再将签名清单原样提交到更新分支。新清单公开之前，旧清单仍指向可用的旧版 DMG，避免更新读取尚未发布的文件。GitHub Raw 的缓存可能使新清单延迟数分钟出现。

发布任务串行运行。更新分支不触发常规 CI，不需要 GitHub Pages 或额外访问凭据。保持仓库公开；App 不内置 GitHub token。

## 签名与验证

使用 [Sparkle 2.10.0](https://sparkle-project.org/documentation/) 官方二进制及工具，SwiftPM 固定版本和官方 SHA-256。第三方许可随 App 分发。

- 公钥：`Resources/Info.plist` 的 `SUPublicEDKey`。
- 私钥：开发机钥匙串账户 `monaco-io.PulseBar`，以及仓库 Actions Secret `SPARKLE_PRIVATE_KEY`。PR 和常规 CI 不读取私钥。
- `generate_appcast` 对 DMG 和 feed 签名，`sign_update --verify` 做密码学校验，`verify-release.py` 检查安装包和清单一致。
- `SURequireSignedFeed` 和 `SUVerifyUpdateBeforeExtraction` 保持开启。不要手改签名后的 XML，不要覆盖已发布的 DMG。

安全保留原签名密钥。迁移开发机可使用 Sparkle `generate_keys` 导出 / 导入；私钥不进入代码、附件、日志或聊天。

## 本地打包

钥匙串已有上述账户时：

```sh
./scripts/package-release.sh v1.7.1
```

脚本只生成本地文件，正式发布由 tag 工作流完成。内部构建仍可生成 ZIP 作为 CI 预览，它不会出现在 Release 中。

## 失败恢复

测试或打包失败时不发布新版；修复后重跑任务。存在同名 Release 时脚本停止，避免覆盖。

如果 DMG 已公开但 feed 推送失败，旧 feed 保持可用。确认 `dist/updates/appcast.xml` 的签名、版本及已公开的 DMG 地址后，将该文件原样提交并推送到 `codex/updates` 分支即可恢复；不要重新打包覆盖 DMG。已发布版本有问题时发布更高版本修复。

## Apple 公证

目前为 ad-hoc 签名，尚无 Apple Developer ID 公证。首次安装可能需要按 [Apple 安全设置说明](https://support.apple.com/102445)允许打开。

本地构建支持 `CODE_SIGN_IDENTITY` 按从内到外的顺序签名 helpers、framework 和 App 并启用 Hardened Runtime；打包支持 `NOTARY_KEYCHAIN_PROFILE` 提交公证并装订票据后生成 DMG。GitHub 托管构建尚未配置 Apple 证书和公证凭据。
