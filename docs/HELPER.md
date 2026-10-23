# PulseBar Helper

The Mac App Store edition of PulseBar uses a separately installed helper for app usage rankings and hardware temperatures. CPU, memory, disk, network, supported GPU/battery readings, charts, and performance events remain available without the helper.

## Install and enable

1. In PulseBar Settings, choose **Download Helper Installer**. This [direct PKG download](https://github.com/monaco-io/PulseBar/releases/download/helper-v1.0.2/PulseBar-Helper.pkg) skips the GitHub release page.
2. Open **PulseBar-Helper.pkg** and follow macOS Installer. It places the helper in your personal **Applications** folder without dragging files or administrator access.
3. Return to PulseBar Settings and choose **Open Helper**, read its explanation, and choose **Enable Helper**.
4. If macOS asks for background-item approval, allow PulseBar Helper in **System Settings → General → Login Items & Extensions**. The helper window links to the relevant system settings.
5. PulseBar reconnects automatically. App rankings populate after a sampling interval; temperatures appear where supported sensors are available.

The Store app opens the direct download in your browser; macOS Installer handles installation after you open the downloaded package. It does not silently download or execute a plugin inside the Store app. The script-free installer never enables the background service on its own.

When the helper is already enabled, **Enable Helper** is disabled. Choose **Open PulseBar** to see the readings; enabling the helper does not open the monitor automatically. If approval is pending, the enable button opens the required system settings.

The main app is distributed and updated only through the Mac App Store. GitHub releases now contain only the helper.

The helper supports macOS 13 or later on Apple Silicon and Intel. Temperature availability varies by hardware and macOS version. It does not provide fan control or elevate privileges.

## Disable or remove

Open **PulseBar Helper** and choose **Disable Helper**. Once disabled, quit the helper and move it to Trash. PulseBar continues with its basic monitoring features. Enable the helper again if you want to restore rankings and temperatures.

To update the helper, disable it, quit its window, run the newer official PKG installer, then launch it and enable it again. The App Store updates the main PulseBar app separately.

The helper retains the v2 launch-agent registration and keeps the same local connection endpoint, so existing App Store versions remain compatible. This avoids reusing a stale registration from the first helper version.

## Privacy and troubleshooting

The helper samples only when PulseBar requests a reading. It communicates locally, accepts the signed PulseBar app from the same developer team, and does not send monitoring data over the network. See the [privacy policy](PRIVACY.md).

If the connection is unavailable, check that the helper is in Applications, enabled, and allowed as a background item. An incompatible or unsigned replacement is rejected. Closing the helper window does not disable its registered background service; use **Disable Helper** to stop it.

[Report a problem](https://github.com/monaco-io/PulseBar/issues) with the app/helper versions and macOS version. Do not post unredacted diagnostic samples containing app names or other personal details.
