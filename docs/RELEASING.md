# GitHub releases and updates

English | [简体中文](RELEASING.zh-CN.md)

## Release layout

**Upload only `PulseBar.dmg` to each Release.** Installation and in-app updates use the same signed DMG. Installation instructions are included in the disk image; release notes belong in the release body. Do not upload ZIPs, separate notes, or checksum files. GitHub displays the asset digest and automatically adds two source archive links.

The signed update feed is stored on the `codex/updates` branch:

<https://raw.githubusercontent.com/monaco-io/PulseBar/codex/updates/appcast.xml>

The app's `SUFeedURL` points to that fixed address. Each feed entry downloads the DMG from a specific version tag. Version 1.7.0 used a release attachment as its feed URL; versions 1.7.0 and earlier need one manual installation of 1.7.1 or later to migrate.

## Default language

Use English for the repository description, default README, installation guide, release titles, release bodies, and embedded update notes. Provide Chinese content in separate `*.zh-CN.*` files linked from the English pages. Do not append the full Chinese translation to default release notes or the update feed. App localization remains available through its language setting.

## Publishing a version

1. Increase both `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
2. Add English notes in `docs/releases/vVERSION.md`, with an optional link to `vVERSION.zh-CN.md`. Commit the changes and confirm CI passes.
3. Create and push the matching tag, for example:

   ```sh
   git tag -a v1.7.2 -m 'PulseBar 1.7.2'
   git push origin v1.7.2
   ```

**Publish release** validates increasing versions, runs tests, builds both architectures, and samples the packaged app. Packaging creates `dist/release/PulseBar.dmg` and `dist/updates/appcast.xml`, checking the mounted app, resources, system requirements, versions, and signatures.

The workflow uploads the DMG as a draft, publishes it as Latest, then commits the signed feed to the update branch. Until that feed is published, the previous feed still points to the previous downloadable DMG. GitHub Raw caching may delay the new feed by several minutes. Before removing older releases, verify that the public feed points to the retained release.

Release jobs run serially. The update branch does not trigger normal CI. No GitHub Pages deployment or extra app credentials are required. Keep the repository public; the app contains no GitHub token.

## Signing and verification

Use the official [Sparkle 2.10.0](https://sparkle-project.org/documentation/) distribution. SwiftPM pins its version and official SHA-256; third-party licenses are bundled with the app.

- Public key: `SUPublicEDKey` in `Resources/Info.plist`.
- Private key: the developer's Keychain account `monaco-io.PulseBar` and the repository Actions secret `SPARKLE_PRIVATE_KEY`. Pull requests and regular CI do not access it.
- `generate_appcast` signs the DMG and feed. `sign_update --verify` verifies signatures; `verify-release.py` checks package and feed consistency.
- Keep `SURequireSignedFeed` and `SUVerifyUpdateBeforeExtraction` enabled. Editing signed XML requires signing it again. Never replace an already-published DMG.

Preserve the signing key securely. Sparkle's `generate_keys` can export/import it when moving developer machines. Private keys must never enter source files, release attachments, logs, or chat.

## Local packaging

With the signing account available in Keychain:

```sh
./scripts/package-release.sh v1.7.1
```

This creates local files; the tag workflow performs publication. Internal builds may produce a development ZIP, which is never uploaded to a Release.

## Recovery and release-note edits

Failed tests or packaging stop publication. Fix the problem before retrying. An existing Release with the same tag stops the workflow to avoid replacing its artifacts.

If the DMG is public but publishing the feed fails, the old feed stays available. Verify the new feed's signature, version, and public DMG URL, then commit that exact feed to `codex/updates`. Do not rebuild or replace the DMG. Fix problems in an app release with a higher version.

To change notes for an existing version, update the source Markdown and GitHub release body. Replace only the feed description, preserving the version and enclosure URL, length, and signature; sign the modified feed again and verify it before publishing. The existing DMG remains byte-for-byte unchanged.

## Apple notarization

Releases currently use ad-hoc signing and are not Apple notarized. First launch may require approval through [Apple's security settings](https://support.apple.com/102445).

Local builds support `CODE_SIGN_IDENTITY` to sign helpers, the framework, and the app from the inside out with Hardened Runtime. Packaging supports `NOTARY_KEYCHAIN_PROFILE` to submit for notarization and staple the ticket before creating the DMG. Apple signing and notarization credentials are not configured on GitHub-hosted runners.
