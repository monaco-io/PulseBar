# PulseBar privacy policy

Last updated: October 14, 2026

This policy covers the Mac App Store edition of PulseBar and the optional PulseBar Helper distributed by Xuze Lu.

## Monitoring stays on your Mac

PulseBar does not operate an account system, advertising service, analytics service, or monitoring-data server. Neither the App Store app nor PulseBar Helper sends monitoring data to the developer or another party.

The app reads CPU, memory, disk, network-interface, GPU, and internal-battery statistics to display them locally. Network monitoring reads byte counters; it does not inspect packets, websites, messages, or browsing content.

If you separately install and enable PulseBar Helper, it reads accessible process resource counters and hardware temperature sensors. It sends app names, resource usage, and available temperatures only to the signed PulseBar app running under the same macOS user. It does not read process command lines or the contents of your documents. Some processes and sensors may be inaccessible or unsupported.

## Local storage and controls

Preferences are stored in the app's local container. Live charts remain in memory and clear when the app exits. Performance events can include resource readings and app names from a top-app snapshot. The app retains up to seven days and 200 events locally. Use **Events → Clear events** to remove the saved event history. Reset clears live charts and session counters without deleting events.

Notifications are optional and off by default. Login startup is optional. PulseBar Helper runs as a service for your macOS user only after you choose **Enable Helper**; it does not require administrator privileges. It samples only when requested by PulseBar. Use **Disable Helper** in the helper app to unregister the service before removing the helper.

## Updates and external links

The App Store app receives updates through Apple's App Store. The helper is downloaded separately from the project's GitHub release page. Opening a support, privacy, or download link opens your browser; the destination's own privacy policy applies to that visit. No monitoring data is included in these links.

The separate GitHub edition of PulseBar uses Sparkle for software updates and is described in the repository README. Its update behavior is not part of the App Store edition.

## Contact

For privacy questions, [open an issue on the PulseBar project](https://github.com/monaco-io/PulseBar/issues). GitHub issues are public; do not include sensitive information or unredacted diagnostic samples.

Material changes to this policy will be documented here with an updated date.
