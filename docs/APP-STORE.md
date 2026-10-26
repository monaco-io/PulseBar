# Mac App Store distribution

The App Store target and the direct GitHub target share the UI and pure metric models. The App Store target links `HelperIPC`; the direct target links `HardwareReaders` and Sparkle. `HardwareReaders` contains process enumeration, the optional responsibility SPI, and AppleSMC access. It is not linked into the App Store app.

## Identities and packages

| Item | Identifier | Distribution |
| --- | --- | --- |
| Store app | `io.github.monaco-io.PulseBar` | Mac App Store distribution signature; `PulseBar-AppStore.pkg` |
| Helper app | `io.github.monaco-io.PulseBar.Helper` | Developer ID Application; notarized `PulseBar-Helper.pkg` |
| Helper service | `io.github.monaco-io.PulseBar.HelperService` | Nested Developer ID executable in the separate helper app |

Team: `45Y6A23PTN`. Service: `45Y6A23PTN.io.github.monaco-io.PulseBar.HelperService`.

The store app enables App Sandbox and one exact `mach-lookup.global-name` temporary exception. The helper uses `SMAppService.agent` with an in-bundle LaunchAgent. Registration requires an explicit Enable action in the helper. The script-free PKG installs only the helper into the current user’s Applications folder, without root privileges or launch-on-install actions. The Store app opens the direct PKG URL in the browser; it has no downloader, installer execution, broad filesystem entitlement or network entitlement.

XPC enforces the expected Apple signature, team, and identifier on both sides using the public macOS 13 code-signing requirement APIs. The companion must use our Developer ID Application certificate. The client may use our Developer ID signature for local testing, or Apple's Mac App Store signature with the exact full application-identifier entitlement after store re-signing. A leaf-certificate OU check alone would reject an App Store download; see [Apple TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements). It additionally checks that the connection uses the same Unix user. The interface has one read-only sampling operation; callers cannot execute commands, supply paths, modify files, or control processes. The client rejects oversized, stale, incompatible, or invalid samples and clears unavailable readings. Test-only exact-code-hash pins are compiled out of release builds.

## Local verification

```sh
./scripts/swift-local.sh test --disable-xctest --jobs 4
PULSEBAR_DISTRIBUTION=app-store ./scripts/swift-local.sh test --disable-xctest --jobs 4 --scratch-path .build/store-debug
./scripts/build-store-distribution.sh --local --debug
python3 scripts/verify-helper-integration.py
# Optional: exercise production certificate checks with an existing local identity.
python3 scripts/verify-helper-integration.py --identity 'Developer ID Application: YOUR NAME (TEAM ID)'
./scripts/build-store-distribution.sh --local
./scripts/package-helper-release.sh --local
```

The integration test creates a unique temporary launch agent and ad-hoc sandboxed client. It checks a working connection, rejected client and service signatures, and continued basic monitoring after the helper is removed. It unloads its own agent in cleanup and does not register the production helper. The resulting local packages must not be uploaded to Apple or released to users.

The default `--local` build is ad-hoc signed and cannot connect to the publicly distributed helper. For local UI acceptance with the real helper, use `--local --developer-id` with `DEVELOPER_ID_APPLICATION_IDENTITY` set to the existing team certificate. Verify real app rankings and temperatures before installing that candidate. Keep the production signature requirements enabled; an enabled helper can still reject an unsigned client.

The bundle verifier rejects Sparkle, process-reader and temperature-reader symbols in the store app. It checks entitlements, resources, release-only authentication settings, and code signatures. Actual Apple upload validation, production signature checks, Gatekeeper/notarization, and App Review are separate stages.

For listing screenshots, a debug preview bundle can set `PulseBarHardwarePreview` and `PulseBarAppStoreCanvas` to true, with `PulseBarPreviewLanguage` set to `en` or `zh-Hans`. Use a separate preview bundle identifier and capture its 1280-by-800-point window through the UI. The canvas displays the actual sandboxed overview with live readings; it uses isolated preview preferences and event storage. These preview switches are not available in release builds.

## Production signing

Install a Mac App Distribution (or supported Apple Distribution) identity, a Mac Installer Distribution identity, a Developer ID Application identity, and an App Store distribution provisioning profile for the store App ID. Keep private keys in the developer's Keychain. Never commit private keys, profiles, passwords, or notarization credentials.

Set the signing identity names/hashes in `APP_STORE_APPLICATION_IDENTITY`, `APP_STORE_INSTALLER_IDENTITY`, and `DEVELOPER_ID_APPLICATION_IDENTITY`; set `APP_STORE_PROFILE` to the profile path. Then run:

```sh
./scripts/build-store-distribution.sh
```

The main app version and build number both come from `Resources/Info.plist`. Increment the build number for each replacement upload. The helper has its own version, currently 1.0.2/build 3, in the bundle assembly script. Both executables target macOS 13 and include arm64/x86_64. SwiftPM's resource-only bundle receives its own identifier before the store app is signed; the verifier checks nested resource bundle identifiers as well.

If the checkout is in a cloud-synced folder, set `PULSEBAR_STORE_SCRATCH_PATH` to an ordinary local cache directory, such as `$HOME/Library/Caches/PulseBar/store-release`, to keep intermediate build files outside cloud synchronization.
Set `PULSEBAR_STORE_OUTPUT_PATH` to a local cache directory as well to keep signed delivery bundles free of synchronization metadata.

Configure an authorized notarytool Keychain profile without placing credentials in source or logs, set its name in `NOTARY_KEYCHAIN_PROFILE`, set `DEVELOPER_ID_INSTALLER_IDENTITY` to a Developer ID Installer identity, then run:

```sh
./scripts/package-helper-release.sh
```

This notarizes and staples the helper app, creates its per-user PKG, signs it with Developer ID Installer, and notarizes/staples the PKG. It verifies both architectures, package destination, absence of scripts and nested signatures. A non-Accepted result stops packaging. Confirm production helper registration, ranking/temperature readings, disable, and reconnect on a clean user account before publishing.

## Publication and review

After the user accepts the latest UI, publish the helper on its own `helper-v1.0.2` tag/release with `PulseBar-Helper.pkg` as its only attached file, using `scripts/publish-helper-release.sh`. Mark it **not Latest** to preserve historical direct-edition links. New main-app releases are distributed only through the Mac App Store; the GitHub app-release workflow is retired. Never replace a published binary; issue a higher helper version for a fix and update the main app's download link when needed.

Publish this support documentation and `PRIVACY.md` before entering their public URLs in App Store Connect. Upload the signed store `.pkg` using Apple's Transporter. Set accurate privacy disclosures and content ratings, add screenshots from the store build, explain the optional helper and the exact Mach exception in App Review notes, and include the helper's public download link. Do not submit while that link is unavailable or its package is not notarized.

`Resources/AppStore/metadata.en-US.json` and `metadata.zh-Hans.json` contain draft listing text and review notes. Review-specific contact data belongs in App Store Connect, not the repository. Pricing, availability, required account agreements, and EU trader status must reflect the account holder's decisions.

The helper architecture and temporary exception require Apple's review. Passing local checks does not establish approval.

## Privacy manifest reasons

The manifest declares app-local preferences (`CA92.1`), sample intervals (`35F9.1`), chart/event timestamps (`8FFB.1`), and displayed disk capacity (`85F4.1`). The store app has no analytics SDK or data collection endpoint. These reasons map to [Apple's required-reason API definitions](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons).

Relevant Apple references: [review guidelines](https://developer.apple.com/app-store/review/guidelines/), [temporary exception entitlements](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html), [build uploads](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).
