# PulseBar

English | [简体中文](README.zh-CN.md)

A native macOS menu bar monitor organized around CPU, memory, GPU, storage, network, and the Mac's internal battery. See which apps use the most resources, inspect linked history charts, review local performance events, and see available hardware temperatures alongside their components.

See [hardware modules and measurement scope](docs/HARDWARE-MODULES.md).

## Download and install

**[Download PulseBar.dmg](https://github.com/monaco-io/PulseBar/releases/latest/download/PulseBar.dmg)** · [Release notes](https://github.com/monaco-io/PulseBar/releases/latest)

Requires **macOS 13 or later**, on **Apple Silicon or Intel**. Open the DMG, drag PulseBar to Applications, and launch it from there. Use `~/Applications` if you do not have administrator access.

The app is ad-hoc signed and is not Apple notarized. If macOS blocks it, verify that the download came from this repository, then choose **System Settings → Privacy & Security → Open Anyway** for PulseBar. See the [installation guide](docs/INSTALL.txt).

### Software updates

Click the menu bar readings, then **Settings → Software update** to check for updates or manage daily checks. When a new version is found automatically, a download hint appears beside Settings. You choose when to download, install, and relaunch. Preferences and local event history are preserved.

**Versions 1.7.0 and earlier need one manual installation of 1.7.1 or later** to migrate to the current update feed.

Updates use [Sparkle](https://sparkle-project.org/) and download the same DMG offered on GitHub Releases. The update feed is hosted separately; both the feed and the DMG are verified with Ed25519 signatures. Checks contact GitHub, with Sparkle system profiling disabled. Monitoring data and event history stay on your Mac.

## Features

- **Hardware modules:** CPU usage and logical cores; memory usage, app/wired/compressed memory, pressure, and swap; GPU utilization per device; startup-volume capacity and physical disk reads/writes; network downloads/uploads and session totals; and internal-battery charge, power state, maximum capacity, cycle count, and system time estimates when available. GPU and battery sections appear only when usable data exists. External batteries and UPS devices are not shown as the Mac's battery.
- **Hardware temperatures:** CPU, GPU, memory, storage, and battery headings show °C only when a known sensor returns a valid reading. Each value is the highest reading among the available sensors mapped to that component. Missing readings leave no temperature placeholder, and the battery heading requires a present internal host battery. Availability varies by Mac and macOS version. See [temperature compatibility](docs/TEMPERATURES.md).
- **Refresh interval:** 2 seconds by default, adjustable from 1 to 60 seconds. Existing custom intervals are preserved.
- **Menu bar controls:** display any combination of CPU, memory, disk, and network readings, with at least one enabled. Hidden menu bar metrics continue sampling and remain visible in the panel.
- **Scrollable overview:** the four CPU, memory, disk, and network history charts remain in their hardware sections. Scroll through modules while the header and navigation stay fixed. Settings, app rankings, and events open in a side panel, one at a time.
- **Top apps:** click the CPU or memory heading or usage value to see the top five apps. Helper processes are grouped with their app where possible; Activity Monitor is one click away.
- **Linked history:** hover over a chart to inspect the same timestamp across all four charts. Live headline readings continue updating. Averages cover sampled time only.
- **Performance events:** record CPU usage of at least 85% for 30 seconds, or elevated/critical memory pressure for 10 seconds, with metrics and top-app snapshots. Snapshots show simultaneous activity without establishing a cause.
- **Local event history:** retain seven days, up to 200 entries, across app restarts. Optional notifications are off by default, with separate cooldowns of 1–60 minutes. Reset preserves event history; clearing events requires confirmation.

## Using PulseBar

Launch `PulseBar.app` to see readings in the menu bar, without a Dock icon. Click the readings to open the panel; click outside or press Escape to close it.

Repeated launches reopen the existing panel. Only one GUI instance runs per macOS user, including when launching updated copies from different folders. The read-only `--sample` diagnostic can run separately.

Use the bottom navigation to switch between **Overview, Apps, Events, and Settings**. Apps has CPU and Memory tabs; clicking either module's heading or usage value is a direct shortcut. The overview is 560 pt wide, with a height capped at 660 pt and the screen's visible height minus 24 pt. Hardware groups retain their headings and dividers without an enclosing card; readings use numbers and text, and histories use lines without filled areas. Available content widths below 500 pt use a single column. The middle content scrolls on smaller screens while the header and navigation stay fixed. Details use a 320 pt side column when the screen accommodates the 881 pt expanded panel; otherwise they stay inside the compact panel.

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

Rates use MB/s; capacities and totals automatically select B, KB, MB, GB, or larger units. Readings use one decimal place and decimal units (`1 GB = 1000 MB`). Very small nonzero rates show `<0.1 MB/s`. CPU and disk need one sampling interval to establish a baseline. Unavailable core usage and I/O metrics show `—` and retry while other metrics continue updating. Missing GPU, capacity, battery, and temperature readings are hidden. Temperatures and GPU statistics run in the background no more frequently than `max(5, Refresh)` seconds; capacity and battery reads use `max(30, Refresh)` seconds. Reset, stop, sleep, and wake clear optional hardware readings and reject results from earlier sampling sessions.

## Build and run

Install Xcode Command Line Tools (`xcode-select --install`). Builds require Swift 6.0 or later. Monitoring uses system frameworks; updates use Sparkle 2.10.0. SwiftPM downloads the pinned official binary dependency and verifies its SHA-256.

```sh
./scripts/build-app.sh
open dist/PulseBar.app
```

The build creates a universal arm64/x86_64 app and a local development ZIP in `dist/`, using ad-hoc signing by default. Sparkle and localized resources are bundled with the app. **GitHub Releases upload only the DMG.** See the [release guide](docs/RELEASING.md) for packaging, update signing, and optional Apple notarization.

```sh
./scripts/swift-local.sh test --disable-xctest
dist/PulseBar.app/Contents/MacOS/PulseBar --sample 5
dist/PulseBar.app/Contents/MacOS/PulseBar --sample 3 --interval 6
```

Diagnostic sampling outputs NDJSON with interface counters, `cpu`, `memory`, `disk`, `memoryPressure`, `swap`, `apps`, `temperatures`, `gpuUsage`, `storageCapacity`, and `battery`. Each temperature entry contains `component`, `celsius`, and contributing `sensorIDs`. GPU entries contain device identity, name, and `utilizationPercent`; capacity contains the sampled volume's name/path and byte counts; battery contains optional charge, power state, maximum-capacity percentage, cycles, and a time estimate in minutes. Missing temperatures/GPU readings produce empty arrays; unavailable capacity/battery produce `null`, and individual unavailable battery fields are also `null`. Optional hardware absence does not cause diagnostic errors. Capacities/totals use bytes, I/O rates use bytes per second, utilization uses 0–100%, and temperatures use °C. Initial CPU/disk rates are `null` while baselines are established. `--interval` affects diagnostic sampling only, including an optional hardware read attempt per sample (subject to temperature-reader retry delays); the panel's slower hardware cadences do not apply. This mode opens no UI, records no events, and sends no notifications. Core metrics fail independently, reporting errors and a nonzero exit code after the remaining sampling completes. See the [diagnostic field reference](docs/HARDWARE-MODULES.md#diagnostic-fields).

The wrapper handles some Command Line Tools installations with duplicate `SwiftBridging` definitions or older `PackageDescription` interfaces. Compatibility files stay in `.build`; system toolchains are untouched. Standard toolchains can also use `swift build` and `swift test` directly.

## Measurement scope and privacy

- **CPU:** differences in Mach `HOST_CPU_LOAD_INFO` counters, normalized across all logical cores to a whole-Mac 0–100% scale.
- **Memory:** `HOST_VM_INFO64` app memory (internal pages minus purgeable pages), wired memory, and physical compressed pages. File cache is excluded, and uncompressed size is not counted again. Usage percentage is separate from memory pressure. See [Apple's memory terminology](https://support.apple.com/guide/activity-monitor/view-memory-usage-actmntr1004/mac).
- **Apps:** accessible process counters from `proc_pid_rusage` and process identity APIs. CPU Mach ticks are converted using `mach_timebase_info`; memory uses `ri_phys_footprint` and cannot be summed to reconcile system memory totals. Exited or inaccessible processes are skipped. Some launchd/XPC services cannot reliably be assigned to their calling app.
- **Pressure and swap:** direct readings from `kern.memorystatus_vm_pressure_level` and `vm.swapusage`. Pressure is never inferred from memory usage percentage.
- **GPU:** driver-reported `PerformanceStatistics` / `Device Utilization %` from named hardware `IOAccelerator` services. Values are shown per device on a 0–100% scale; percentages from multiple GPUs are not added together. These driver keys are not guaranteed across Macs or macOS versions. A component-wide GPU temperature is not attributed to a particular device row.
- **Temperatures:** read-only AppleSMC queries through IOKit. Only known component mappings and supported temperature encodings are accepted; invalid, zero, or unavailable readings are omitted. Each displayed component uses the maximum of its currently valid mapped sensors. Memory pressure and macOS thermal state are never converted into temperatures. Apple Silicon has been sampled locally; Intel temperature sensors have not been tested on Intel hardware. See [implementation and compatibility](docs/TEMPERATURES.md).
- **Storage capacity:** Foundation `volumeTotalCapacity` and ordinary `volumeAvailableCapacity` on `/System/Volumes/Data`, or `/` when there is no separate startup data volume. This is capacity visible to the startup volume, rather than the physical drive's nominal capacity or a sum of APFS volumes. On APFS, unavailable space includes other volumes and snapshots sharing its container. Available space excludes estimated reclaimable space from `volumeAvailableCapacityForImportantUsage`.
- **Disk I/O:** physical-device counters from IOKit's `IOBlockStorageDriver`, without adding APFS volumes or partitions again. Virtual interfaces are excluded; cached reads may not cause physical I/O. This system-wide device activity has a different scope from startup-volume capacity.
- **Network:** kernel `NET_RT_IFLIST2` counters for active `en<N>` interfaces, including Wi-Fi, Ethernet, and common USB adapters. Local traffic and protocol overhead are included. Virtual interfaces are not counted again; VPN transport remains counted on the physical interface.
- **Internal battery:** public IOPowerSources descriptions establish one present internal host battery before optional AppleSmartBattery capacity/cycle metadata is used. Charge and power state use the same public source; time comes from its official charging/discharging estimates. Maximum capacity compares compatible native full-charge and design-capacity values, rather than assigning a health score. Unavailable or incompatible fields are hidden. A desktop without an internal battery has no battery section.

All sampling uses in-process system APIs. PulseBar does not capture packets, read browsing content or process command lines, run active speed tests, send monitoring telemetry, or request administrator access. Process sampling and event writes run on a serial background queue.

Baselines reset after device changes, counter resets, sleep, or interrupted sampling to avoid artificial spikes. Charts preserve peaks when reducing plotted points and exclude missing time from averages. Events use observed sample duration, so longer intervals delay detection and brief events between samples may be missed. Event snapshots are stored atomically in `~/Library/Application Support/PulseBar/events.json` and are never uploaded.

## Localization

Public project information and release notes default to English. Chinese documentation is available through explicit language links. App localization is available through the language setting.

Translations live in `Sources/SpeedCore/Resources/{en,zh-Hans}.lproj/Localizable.strings`; localized app names are in `Resources/*.lproj/InfoPlist.strings`. Settings use UserDefaults. The original NetSpeed bundle identifier is retained to preserve existing preferences and menu bar placement.

PulseBar uses AppKit `NSStatusItem`/`NSPopover` with a SwiftUI panel. Kernel structures follow the installed SDK's `net/if.h` and `net/if_var.h`.
