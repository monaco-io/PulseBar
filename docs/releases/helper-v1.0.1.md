# PulseBar Helper 1.0.1

- Keep the window responsive while enabling or disabling the helper. Show progress and open Login Items settings when background-item approval is required.
- Add an Open PulseBar button and clearer enabled-state guidance.
- Replace stale launch-agent registrations with a new registration identity while preserving the existing authenticated local connection endpoint for current App Store clients.
- Share the sampler and cache across reconnecting clients, and avoid unnecessary filesystem checks when extracting process names.

This optional companion provides app usage rankings and supported hardware temperatures to the Mac App Store edition of PulseBar. It supports macOS 13 or later on Apple Silicon and Intel, runs only as the current user, and does not send monitoring data over the network.

The helper app and disk image are signed with Developer ID, notarized by Apple, and include stapled notarization tickets. Download **PulseBar-Helper.dmg**. Before updating, open the old helper, choose **Disable Helper**, and quit it. Replace **PulseBar Helper.app** in Applications, open it, and choose **Enable Helper**. Allow the background item if macOS requests it, then choose **Open PulseBar**.

[Installation and troubleshooting](https://github.com/monaco-io/PulseBar/blob/helper-v1.0.1/docs/HELPER.md) · [Privacy policy](https://github.com/monaco-io/PulseBar/blob/helper-v1.0.1/docs/PRIVACY.md) · [简体中文](https://github.com/monaco-io/PulseBar/blob/helper-v1.0.1/docs/releases/helper-v1.0.1.zh-CN.md)
