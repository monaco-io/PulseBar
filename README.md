# PulseBar

English | [简体中文](README.zh-CN.md)

A native macOS menu bar monitor for CPU, memory, disk I/O, and network activity. See which apps use the most resources, inspect linked history charts, and review local performance events.

## Download and install

**[Download PulseBar.dmg](https://github.com/monaco-io/PulseBar/releases/latest/download/PulseBar.dmg)** · [Release notes](https://github.com/monaco-io/PulseBar/releases/latest)

Requires **macOS 13 or later**, on **Apple Silicon or Intel**. Open the DMG, drag PulseBar to Applications, and launch it from there. Use `~/Applications` if you do not have administrator access.

The app is ad-hoc signed and is not Apple notarized. If macOS blocks it, verify that the download came from this repository, then choose **System Settings → Privacy & Security → Open Anyway** for PulseBar. See the [installation guide](docs/INSTALL.txt).

### Software updates

Click the menu bar readings, then **Settings → Software update** to check for updates or manage daily checks. When a new version is found automatically, a download hint appears beside Settings. You choose when to download, install, and relaunch. Preferences and local event history are preserved.

**Versions 1.7.0 and earlier need one manual installation of 1.7.1 or later** to migrate to the current update feed.

Updates use [Sparkle](https://sparkle-project.org/) and download the same DMG offered on GitHub Releases. The update feed is hosted separately; both the feed and the DMG are verified with Ed25519 signatures. Checks contact GitHub, with Sparkle system profiling disabled. Monitoring data and event history stay on your Mac.

## Features

- **Live monitoring:** whole-Mac CPU usage, memory used and total, memory pressure, swap usage, physical disk reads/writes, network downloads/uploads, and session totals.
- **Refresh interval:** 2 seconds by default, adjustable from 1 to 60 seconds. Existing custom intervals are preserved.
- **Menu bar controls:** display any combination of CPU, memory, disk, and network readings, with at least one enabled. Hidden menu bar metrics continue sampling and remain visible in the panel.
- **Full chart overview:** all four charts remain visible. Settings, app rankings, and events open in a side panel, one at a time.
- **Top apps:** click the CPU or memory heading to see the top five apps. Helper processes are grouped with their app where possible; Activity Monitor is one click away.
- **Linked history:** hover over a chart to inspect the same timestamp across all four charts. Live headline readings continue updating. Averages cover sampled time only.
- **Performance events:** record CPU usage of at least 85% for 30 seconds, or elevated/critical memory pressure for 10 seconds, with metrics and top-app snapshots. Snapshots show simultaneous activity without establishing a cause.
- **Local event history:** retain seven days, up to 200 entries, across app restarts. Optional notifications are off by default, with separate cooldowns of 1–60 minutes. Reset preserves event history; clearing events requires confirmation.

## Using PulseBar

Launch `PulseBar.app` to see readings in the menu bar, without a Dock icon. Click the readings to open the panel; click outside or press Escape to close it.

Repeated launches reopen the existing panel. Only one GUI instance runs per macOS user, including when launching updated copies from different folders. The read-only `--sample` diagnostic can run separately.

Use the bottom navigation to switch between **Overview, Apps, Events, and Settings**. Apps has CPU and Memory tabs; clicking a metric heading is a direct shortcut. Details share one width, so switching destinations keeps the window stable. On narrow displays, details stay inside the compact panel.

Use **More** in the header for update checks, Reset, and Quit, or right-click the menu bar readings for a shortcut menu. Escape returns to Overview before closing the panel; Command-1 through Command-4 select the main destinations. Native menus handle their own Escape key.

Settings start collapsed whenever the panel opens. Preferences apply immediately and are saved. Opening, detail reveals, and button feedback use brief animations and respect the system Reduce Motion setting.

| Setting | Behavior |
| --- | --- |
| Menu bar display | Toggle CPU, memory, disk, and network readings. |
| Language | Follow System, English, or Simplified Chinese. Changes apply immediately; unsupported system languages fall back to English. |
| Refresh | Sample every 1–60 seconds. Type a value and press Return, or use the stepper. |
| History | Choose up to 24 hours, including decimals: `0.5` means 30 minutes. New installations default to one hour. |
| Launch at login | Use macOS login items to launch PulseBar for your account. Off until enabled; actual system status is shown. |
| Event notifications | Enable notifications for new performance events and choose a cooldown. Permission is requested only when enabled. |
| Software update | Check manually or manage daily automatic checks. |

**Reset** clears charts and session disk/network totals. **Quit** exits the app. Charts retain up to 24 hours from the current run and clear on exit; changing the visible range reuses collected samples without changing the refresh interval. Missing periods are not filled with invented data.

Rates use MB/s; capacities and totals automatically select B, KB, MB, GB, or larger units. Readings use one decimal place and decimal units (`1 GB = 1000 MB`). Very small nonzero rates show `<0.1 MB/s`. CPU and disk need one sampling interval to establish a baseline. Unavailable metrics show `—` and retry while other metrics continue updating.

## Build and run

Install Xcode Command Line Tools (`xcode-select --install`). Builds require Swift 6.0 or later. Monitoring uses system frameworks; updates use Sparkle 2.10.0. SwiftPM downloads the pinned official binary dependency and verifies its SHA-256.

```sh
./scripts/build-app.sh
open dist/PulseBar.app
```

The build creates a universal arm64/x86_64 app and a local development ZIP in `dist/`, using ad-hoc signing by default. Sparkle and localized resources are bundled with the app. **GitHub Releases upload only the DMG.** See the [release guide](docs/RELEASING.md) for packaging, update signing, and optional Apple notarization.

```sh
./scripts/swift-local.sh test --disable-xctest
.build/release/PulseBar --sample 5
.build/release/PulseBar --sample 3 --interval 6
```

Diagnostic sampling outputs NDJSON with interface counters, `cpu`, `memory`, `disk`, `memoryPressure`, `swap`, and `apps`. Raw units are bytes and bytes per second. Initial CPU/disk rates are `null` while baselines are established. `--interval` affects diagnostic sampling only. This mode opens no UI, records no events, and sends no notifications. Metrics fail independently, reporting errors and a nonzero exit code after the remaining sampling completes.

The wrapper handles some Command Line Tools installations with duplicate `SwiftBridging` definitions or older `PackageDescription` interfaces. Compatibility files stay in `.build`; system toolchains are untouched. Standard toolchains can also use `swift build` and `swift test` directly.

## Measurement scope and privacy

- **CPU:** differences in Mach `HOST_CPU_LOAD_INFO` counters, normalized across all logical cores to a whole-Mac 0–100% scale.
- **Memory:** `HOST_VM_INFO64` app memory (internal pages minus purgeable pages), wired memory, and physical compressed pages. File cache is excluded, and uncompressed size is not counted again. Usage percentage is separate from memory pressure. See [Apple's memory terminology](https://support.apple.com/guide/activity-monitor/view-memory-usage-actmntr1004/mac).
- **Apps:** accessible process counters from `proc_pid_rusage` and process identity APIs. CPU Mach ticks are converted using `mach_timebase_info`; memory uses `ri_phys_footprint` and cannot be summed to reconcile system memory totals. Exited or inaccessible processes are skipped. Some launchd/XPC services cannot reliably be assigned to their calling app.
- **Pressure and swap:** direct readings from `kern.memorystatus_vm_pressure_level` and `vm.swapusage`. Pressure is never inferred from memory usage percentage.
- **Disk:** physical-device counters from IOKit's `IOBlockStorageDriver`, without adding APFS volumes or partitions again. Virtual interfaces are excluded; cached reads may not cause physical I/O.
- **Network:** kernel `NET_RT_IFLIST2` counters for active `en<N>` interfaces, including Wi-Fi, Ethernet, and common USB adapters. Local traffic and protocol overhead are included. Virtual interfaces are not counted again; VPN transport remains counted on the physical interface.

All sampling uses in-process system APIs. PulseBar does not capture packets, read browsing content or process command lines, run active speed tests, send monitoring telemetry, or request administrator access. Process sampling and event writes run on a serial background queue.

Baselines reset after device changes, counter resets, sleep, or interrupted sampling to avoid artificial spikes. Charts preserve peaks when reducing plotted points and exclude missing time from averages. Events use observed sample duration, so longer intervals delay detection and brief events between samples may be missed. Event snapshots are stored atomically in `~/Library/Application Support/PulseBar/events.json` and are never uploaded.

## Localization

Public project information and release notes default to English. Chinese documentation is available through explicit language links. App localization is available through the language setting.

Translations live in `Sources/SpeedCore/Resources/{en,zh-Hans}.lproj/Localizable.strings`; localized app names are in `Resources/*.lproj/InfoPlist.strings`. Settings use UserDefaults. The original NetSpeed bundle identifier is retained to preserve existing preferences and menu bar placement.

PulseBar uses AppKit `NSStatusItem`/`NSPopover` with a SwiftUI panel. Kernel structures follow the installed SDK's `net/if.h` and `net/if_var.h`.
