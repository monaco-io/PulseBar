# PulseBar Helper

The Mac App Store edition of PulseBar uses a separately installed helper for app usage rankings and hardware temperatures. CPU, memory, disk, network, supported GPU/battery readings, charts, and performance events remain available without the helper.

## Install and enable

1. Download **PulseBar-Helper.dmg** from the [PulseBar Helper release](https://github.com/monaco-io/PulseBar/releases/tag/helper-v1.0.0).
2. Open the disk image and drag **PulseBar Helper.app** to **Applications**. You can use your user's Applications folder if you do not have administrator access.
3. Launch **PulseBar Helper**, read the explanation, and choose **Enable Helper**.
4. If macOS asks for background-item approval, allow PulseBar Helper in **System Settings → General → Login Items & Extensions**. The helper window links to the relevant system settings.
5. Open PulseBar. Its helper settings show when the connection is established. App rankings populate after a sampling interval; temperatures appear where supported sensors are available.

The helper supports macOS 13 or later on Apple Silicon and Intel. Temperature availability varies by hardware and macOS version. It does not provide fan control or elevate privileges.

## Disable or remove

Open **PulseBar Helper** and choose **Disable Helper**. Once disabled, quit the helper and move it to Trash. PulseBar continues with its basic monitoring features. Enable the helper again if you want to restore rankings and temperatures.

To update the helper, disable it, quit its window, replace the app using the newer official disk image, then launch it and enable it again. The App Store updates the main PulseBar app separately.

## Privacy and troubleshooting

The helper samples only when PulseBar requests a reading. It communicates locally, accepts the signed PulseBar app from the same developer team, and does not send monitoring data over the network. See the [privacy policy](PRIVACY.md).

If the connection is unavailable, check that the helper is in Applications, enabled, and allowed as a background item. An incompatible or unsigned replacement is rejected. Closing the helper window does not disable its registered background service; use **Disable Helper** to stop it.

[Report a problem](https://github.com/monaco-io/PulseBar/issues) with the app/helper versions and macOS version. Do not post unredacted diagnostic samples containing app names or other personal details.
