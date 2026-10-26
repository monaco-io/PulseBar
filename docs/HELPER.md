# PulseBar Helper

PulseBar Helper provides app rankings and hardware temperatures. Basic monitoring works without it.

## Install and enable

1. In PulseBar Settings, choose **Download Helper**, or [download the PKG](https://github.com/monaco-io/PulseBar/releases/download/helper-v1.0.2/PulseBar-Helper.pkg).
2. Open the PKG and follow Installer. The helper installs in your home folder’s **Applications** folder.
3. Choose **Open Helper** in PulseBar Settings, then **Enable Helper**. If the button fails, open `~/Applications/PulseBar Helper.app` in Finder.
4. If prompted, allow the helper in **System Settings → General → Login Items & Extensions**.

PulseBar reconnects automatically. App rankings appear after a sampling interval; temperatures depend on available sensors.

Requires macOS 13 or later, Apple Silicon or Intel. No administrator access is required. Data stays on your Mac.

## Disable or remove

Choose **Disable Helper**, quit it, then move it to Trash. Closing its window alone leaves the background service enabled.

To update, disable and quit the helper, install the newer PKG, then enable it again. PulseBar updates separately through the App Store.

## Privacy and troubleshooting

The helper communicates locally with the signed PulseBar app. See the [privacy policy](PRIVACY.md).

If disconnected, check that the helper is installed, enabled and allowed as a background item.

[Report a problem](https://github.com/monaco-io/PulseBar/issues) with your PulseBar, helper and macOS versions.
