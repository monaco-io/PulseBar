# GitHub 发布与更新

仓库：<https://github.com/monaco-io/PulseBar>

## 日常发布

1. 在 `Resources/Info.plist` 中提高 `CFBundleShortVersionString`（例如 `1.7.1`）和 `CFBundleVersion`（例如 `14`）。版本号与构建号都必须高于上一稳定版；不要复用版本或覆盖已发布安装包。
2. 添加 `docs/releases/v1.7.1.md` 版本说明，提交代码并确保 main 上的 **Build and test** 成功。
3. 创建并推送对应 tag：

   ```sh
   git tag -a v1.7.1 -m 'PulseBar 1.7.1'
   git push origin v1.7.1
   ```

**Publish release** 会核对 tag、版本及递增的构建号，运行测试，编译 arm64 / x86_64 通用 App，诊断采样，生成安装包并签名，再上传为草稿。全部文件上传完毕才公开为 Latest，避免客户端读取尚未齐全的版本。所有 Actions 固定到提交 SHA。

每版提供：`PulseBar.dmg`、`PulseBar.zip`、`appcast.xml`、`SHA256SUMS.txt`、`INSTALL.txt`、`RELEASE_NOTES.md`。下载按钮固定使用 `releases/latest/download/PulseBar.dmg`，更新入口固定使用 `releases/latest/download/appcast.xml`；更新清单内的 ZIP 地址指向具体 tag，避免版本混用。当前 feed 只保留最新稳定版，不生成差分更新；以后如提高最低系统版本，需要在发布脚本中保留兼容旧系统的 feed 条目。

## 更新签名

使用 [Sparkle 2.10.0](https://sparkle-project.org/documentation/) 官方二进制及工具。`Package.swift` 固定版本和官方 SHA-256，无需完整 Xcode 即可构建。第三方许可位于 `Resources/Sparkle-LICENSE.txt`，并随 App 分发。

- 公钥：`Resources/Info.plist` 中的 `SUPublicEDKey`。
- 私钥：开发机钥匙串中的 Sparkle 账户 `monaco-io.PulseBar`，以及当前仓库的 Actions Secret `SPARKLE_PRIVATE_KEY`。
- 私钥仅传给 tag 发布工作流中的签名步骤；PR 与常规 CI 不获得私钥。
- `generate_appcast` 同时签名 ZIP 和 feed；`sign_update --verify` 在发布前进行密码学校验。另校对版本、系统要求、文件长度、打包资源和 SHA-256。
- `SURequireSignedFeed` 和 `SUVerifyUpdateBeforeExtraction` 均开启。不要手改已签名的 XML，也不要在发布后用同名文件替换安装包。

保留并安全备份原签名密钥。未来迁移开发机时使用 Sparkle `generate_keys` 的导出 / 导入功能；不要把私钥写入代码、release 附件、日志或聊天。使用同一公钥持续发布，否则已安装的客户端会拒绝更新。

## 本地构建发布文件

在钥匙串已有上述账户的 Mac 上：

```sh
./scripts/swift-local.sh test --disable-xctest
./scripts/package-release.sh v1.7.0
```

文件位于 `dist/release/`。脚本不上传，正式上传由 tag 工作流完成。

## Apple 签名与公证

目前仓库未配置 Apple Developer ID 证书，因此 GitHub 产物采用 ad-hoc 签名，**不属于 Apple 已公证应用**。Sparkle 的更新签名可校验后续更新来源，首次安装仍需按 [Apple 的安全设置说明](https://support.apple.com/102445)允许打开。

如以后有 Developer ID，构建脚本支持 `CODE_SIGN_IDENTITY`，按从内到外顺序签名 Sparkle helpers、framework 和 App 并启用 Hardened Runtime。本地打包还支持 `NOTARY_KEYCHAIN_PROFILE`，用 `notarytool` 提交并装订票据后再生成最终 ZIP / DMG。GitHub 托管构建需另行配置证书导入、临时钥匙串和公证凭据；当前工作流没有这些凭据，也不会把未公证状态报成已公证。

## 失败恢复

- 测试、打包或校验失败不会发布新版。修复后可重跑失败工作流，或在 Actions 手动指定已有 tag。
- 若上传中断留下 Draft，先检查草稿及资产；脚本遇到同名 Release 会停止，避免覆盖。确认未发布的残留草稿后再处理重试。
- 已公开版本有问题时，发布更高版本修复；不要降低构建号或改写已发布 tag。
- 仓库需要保持公开，否则下载与更新清单的匿名 HTTPS 请求将失败。App 不内置 GitHub token。

## 验收

验证工作流成功、Release 对应提交、匿名下载可用、校验文件匹配，以及安装包中的双架构与签名。再从已安装的 App 打开“检查更新”，验证“已是最新版”；使用构建号较低的本地测试副本验证发现新版、下载、安装并重启。测试副本不得上传成稳定 Release。
