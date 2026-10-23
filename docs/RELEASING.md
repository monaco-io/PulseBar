# Distribution and releases

English | [简体中文](RELEASING.zh-CN.md)

## Distribution policy

PulseBar and its updates are distributed only through the **Mac App Store**. GitHub releases contain only the optional **PulseBar Helper**. The former `v*` main-app release workflow has been removed, and `scripts/package-release.sh` refuses to create another main-app release. CI verifies the Store build and helper without uploading a main-app archive.

Historical app releases and the `codex/updates` Sparkle feed remain unchanged for existing installations. Do not replace or delete published files or rewrite that feed as part of a helper release. Helper releases must use `--latest=false` so legacy `releases/latest` clients are not redirected to a plugin.

## Main app

1. Complete source checks, build the candidate, and show the latest real UI for acceptance.
2. After UI acceptance, increment the main app version/build in `Resources/Info.plist` as needed and follow [App Store distribution](APP-STORE.md).
3. Upload and submit through Apple's tools. The App Store distributes app updates; no GitHub app archive or Sparkle feed is published.

## Helper installer

Use a new `helper-vVERSION` tag for each release. The only release attachment is **PulseBar-Helper.pkg**, signed with Developer ID Installer and notarized/stapled by Apple. The nested helper app and service use Developer ID Application. The PKG is script-free and installs only the helper into `~/Applications`, without administrator access or automatically enabling a service. Its installer has English and Simplified Chinese instructions.

The main app opens the version-pinned **direct PKG download**, rather than a GitHub page. An installed helper opens from Settings. Keep the Swift `HelperIdentity.version`, helper bundle version in `build-store-distribution.sh`, installer and release tag aligned. Never upload the main App Store submission PKG to GitHub.

```sh
./scripts/build-store-distribution.sh
./scripts/package-helper-release.sh
```

Production packaging requires the App Store signing/profile inputs documented in [APP-STORE.md], plus `DEVELOPER_ID_INSTALLER_IDENTITY` and `NOTARY_KEYCHAIN_PROFILE`. Store credentials only in the local Keychain or authorized secret storage. Missing signatures, notarization failures, and payload verification failures stop packaging.

After the user has accepted the UI and release checks pass:

```sh
git tag -a helper-v1.0.2 -m 'PulseBar Helper 1.0.2'
git push origin helper-v1.0.2
./scripts/publish-helper-release.sh helper-v1.0.2
```

The publication script verifies the actual PKG payload, notarization, Developer ID Installer team, matching tag/version and clean tracked source. It uploads a draft with exactly one installer and then publishes it as not Latest. An existing release stops creation instead of replacing a published installer. No GitHub-hosted Apple signing credentials are needed.

After publication, verify the anonymous direct download URL, asset digest and notarization. Only then submit the main app with the matching helper link. Do not publish or submit while the user's requested UI acceptance is pending.

## Local validation

```sh
./scripts/build-store-distribution.sh --local
./scripts/package-helper-release.sh --local
python3 scripts/verify-helper-installer.py dist/helper-release/PulseBar-Helper.pkg
```

Local packages are marked `LOCAL-ONLY.txt` and cannot pass the publication script. Inspecting a package does not install it, register a background item, establish App Review approval or prove a public download.

Default repository and release text is English, with Chinese versions linked separately. Monitoring data and event history stay local.
