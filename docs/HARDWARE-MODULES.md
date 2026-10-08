# Hardware modules

Version 1.10.0 introduced hardware groups. Version 1.11.0 retains their internal layout and removes the surrounding hardware-card frame. This document describes the current layout, measurement scope, and availability; application validation is recorded separately in [VALIDATION.md](VALIDATION.md).

## Overview and availability

The panel retains CPU, memory, GPU, storage, network, and internal-battery contents, hardware headings, hierarchy, and horizontal and vertical dividers. CPU and optional GPU occupy the upper left, memory and optional battery the upper right, with storage and network below. Only the `RoundedRectangle` background and `strokeBorder` around all of `hardwareContent` are removed; the transparent `VStack` remains inside the native panel. Optional groups leave no reserved slots; a Mac without a present internal battery has no battery group. GPU utilization names each reported device, while component temperatures appear in their own hardware headings without attribution to a particular GPU device. CPU and memory headings and usage values keep their Apps shortcuts.

The overview is 560 pt wide and at most 660 pt high, further limited to the screen's visible height minus 24 pt. Available content widths below 500 pt use one scrolling column. Internal typography remains 22 pt for primary values, 20 pt for rates, and 11 pt for body labels and statistics, using native SF type and semantic system colors. The layout aims to show every available reading together on common screens; short screens, longer labels, or additional hardware retain a scrolling middle-content fallback between the fixed header and bottom navigation. A 320 pt detail column opens when the screen can accommodate the 881 pt expanded width; narrow screens use inline details. New sensor readings do not resize an open window.

Percentages, capacity, and charge use numeric values; pressure and power state use text. The overview contains no progress views or occupancy/fill bars. The existing four CPU/memory/disk/network histories remain pure line charts without area fills, preserving linked inspection and time context. Sampling, menu-bar options, saved preferences, and the performance-event schema are unchanged. Version 1.11.0 fixes English Events empty-state text wrapping in narrow panels. Version 1.10.0 used a 400 pt overview with an 820 pt maximum height; those dimensions remain only in the historical design notes.

| Module | Source | Display and units | Missing-data behavior |
| --- | --- | --- | --- |
| CPU | Mach `HOST_CPU_LOAD_INFO`; `ProcessInfo.processorCount` | Interval usage normalized across all logical cores, 0–100%; user/system percentages; logical cores; existing history; mapped temperature in °C | CPU requires a baseline interval. Read errors show `—` and a local error; missing temperature is omitted. |
| Memory | Mach `HOST_VM_INFO64` and physical memory; `kern.memorystatus_vm_pressure_level`; `vm.swapusage` | Used/total, app/wired/compressed bytes, usage percentage, pressure level, swap bytes, existing history; mapped temperature in °C | Core read errors remain local; optional temperature is omitted. Pressure is separate from utilization. |
| GPU | Named `IOAccelerator` services and driver `PerformanceStatistics` | Per-device `Device Utilization %`, 0–100%; component-wide mapped temperature in °C | A missing model or invalid/missing device-utilization value omits that row. The group appears if utilization or a GPU temperature exists. |
| Storage | Foundation startup-volume resource values; IOKit `IOBlockStorageDriver` | Startup-volume used/total/available bytes and occupancy percentage; separately labeled physical read/write B/s, existing history, session byte totals; mapped temperature in °C | Invalid/unreadable capacity is omitted. Disk I/O retains its existing baseline/error behavior. |
| Network | Kernel `NET_RT_IFLIST2` for active `en<N>` interfaces | Download/upload B/s, existing history, session byte totals, interface names | Existing interface/error behavior is retained. |
| Internal battery | Public IOPowerSources, optional AppleSmartBattery properties, mapped AppleSMC sensor | Charge and maximum-capacity percentage; power state; cycle count; official time estimate in minutes; temperature in °C | No present internal battery means no battery group. Each invalid/unavailable field is omitted; no usable fields means no battery group. |

The UI formats rates as MB/s and byte quantities in decimal B/KB/MB/GB or larger units, with one decimal place. A genuine idle 0% GPU, fully used volume with zero available bytes, empty volume, or zero-cycle battery is valid. Invalid temperature zeroes are excluded by the temperature reader rather than shown as measured values.

## GPU scope

[GPUReader.swift](../Sources/SpeedCore/GPUReader.swift) makes read-only IORegistry calls and keeps each accelerator's registry identity. Its `PerformanceStatistics` keys are driver-specific and are not a stable, guaranteed GPU metrics API. [GPUMetrics.swift](../Sources/SpeedCore/GPUMetrics.swift) accepts only a valid hardware model and finite device utilization in 0–100%; software/virtual/unknown models and malformed readings are excluded. The code does not substitute renderer-only utilization or add percentages from separate GPUs.

The heading's GPU temperature is the highest accepted mapped GPU sensor, following the existing temperature reader. It describes the GPU component category; it is not tied to the named utilization row or a particular accelerator on a multi-GPU Mac. Intel/AMD driver variations may expose no usable utilization.

A production-reader probe on the development M4 Mac returned a named Apple M4 GPU and valid device utilization values of 83%, 100%, and 0%. Read time was approximately 2.2 ms initially and 0.27/0.10 ms in subsequent samples. These are individual observed samples, not a benchmark or a guarantee for other drivers.

## Startup-volume capacity and disk I/O

[StorageCapacity.swift](../Sources/SpeedCore/StorageCapacity.swift) selects `/System/Volumes/Data` when that directory exists, otherwise `/`. It reads a fresh URL's `volumeTotalCapacity`, ordinary `volumeAvailableCapacity`, name, and local-volume flag. It does not enumerate and sum APFS volumes or scan user files. A nonpositive total, negative available space, available greater than total, nonlocal volume, or failed resource query produces no capacity reading.

`usedBytes = totalBytes - availableBytes`; `usedPercent = usedBytes / totalBytes × 100`. These describe space visible to the startup volume. With APFS, that space can be shared with other volumes and snapshots, so this is not the startup Data volume's own file-size sum or the physical disk's nominal capacity. [Apple's ordinary available-capacity property](https://developer.apple.com/documentation/foundation/urlresourcevalues/volumeavailablecapacity) reports free space; [important-usage capacity](https://developer.apple.com/documentation/foundation/urlresourcevalues/volumeavailablecapacityforimportantusage) includes space expected to become available by purging caches and other nonessential resources. PulseBar uses the ordinary value and excludes that estimate.

The physical disk I/O row retains the established `IOBlockStorageDriver` counters, aggregated once per eligible hardware device. Its system-wide scope is different from the startup-volume capacity row. Cached file activity may not generate physical I/O. See [SystemReader.swift](../Sources/SpeedCore/SystemReader.swift).

A read-only Foundation probe on the development Mac returned startup Data volume total `494384795648 B` and available `7127040000 B`; a same-time `statfs` read matched both values exactly. Available bytes are a changing observation, not a fixed machine specification. Twenty resource queries averaged 5.88 ms. This confirms the chosen capacity semantics on that host, without establishing all APFS quota/container configurations.

## Internal battery

[BatteryReader.swift](../Sources/SpeedCore/BatteryReader.swift) first reads `IOPSCopyPowerSourcesInfo` / `IOPSCopyPowerSourcesList` / `IOPSGetPowerSourceDescription`. [BatteryMetrics.swift](../Sources/SpeedCore/BatteryMetrics.swift) requires exactly one source with `kIOPSInternalBatteryType` and a true `kIOPSIsPresentKey`. A UPS, external power source, or peripheral battery cannot create this group. AppleSmartBattery registry services are queried only after that internal-source check succeeds.

- Charge is `kIOPSCurrentCapacityKey / kIOPSMaxCapacityKey × 100` from the same public source, with a positive maximum and current within range.
- Power state distinguishes charging, full, running on battery, and external power using the public supply/charging/charged flags. Ambiguous state is omitted.
- Maximum capacity is native full-charge capacity divided by native design capacity. Prefer `AppleRawMaxCapacity`; fall back to `MaxCapacity` only when it is a compatible native capacity, not a normalized public percentage. Implausible units or ratios are omitted; accepted values above rated design capacity display at most 100%. This is retained capacity, not a general battery-health score.
- Cycle count comes from one installed AppleSmartBattery service and requires an integer in the accepted range. An unavailable count is not replaced with zero.
- Time comes directly from `kIOPSTimeToFullChargeKey` while charging or `kIOPSTimeToEmptyKey` while discharging. Only positive, plausible integer minutes are displayed; calculating/unknown sentinels are hidden. PulseBar does not compute a countdown from charge percentage.
- Temperature comes from the existing mapped AppleSMC battery sensors, but only appears in the panel once the internal-battery gate is established.

The implementation is best effort across Intel and Apple Silicon. MacBook charge, native capacity, cycle, time, and battery-temperature behavior have not been verified on a physical MacBook in this development round. A read-only probe on the development iMac found zero public power sources and zero internal host batteries, despite one matching AppleSmartBattery registry service. Registry-service presence alone does not satisfy the internal-battery gate. A desktop without an internal battery is expected to return `nil`; the unified production diagnostic is recorded in `artifacts/hardware-modules/diagnostic.ndjson`, with its result tracked in [VALIDATION.md](VALIDATION.md).

## Sampling and lifecycle

Core CPU/memory/disk/network sampling retains the configured 1–60 second Refresh interval and established baselines. GPU and temperatures are scheduled no faster than `max(5, Refresh)` seconds; startup-volume capacity and battery use `max(30, Refresh)` seconds. Reads run on serial background queues with at most one request in flight per queue. The main thread only publishes completed readings.

Stop, Reset, sleep/wake, or an excessive sampling gap clears optional hardware values. Generation checks reject completions from an earlier sampling session, and callbacks that became too old are discarded. A scheduled read that returns `nil` or an empty array clears the previous value. These paths avoid retaining an apparently live GPU, capacity, battery, or temperature after its source stops responding.

The existing AppleSMC reader additionally backs off when no supported sensors are accessible. See [temperature validity and compatibility](TEMPERATURES.md). No subprocess sampler, privileged helper, administrator access, security-setting change, or new persistent permission is introduced.

## Diagnostic fields

`PulseBar --sample <1...60> [--interval <1...60>]` emits NDJSON and attempts optional hardware reads once per diagnostic sample. The panel's 5/30-second minimum cadences do not apply; the AppleSMC reader's failure/retry delays still do. This read-only mode opens no UI and records no performance events.

| Field | Shape | Absence |
| --- | --- | --- |
| `gpuUsage` | `[{id, name, utilizationPercent}]`, per hardware device | `[]` |
| `storageCapacity` | `{name, path, totalBytes, availableBytes, usedBytes, usedPercent}` | `null` |
| `battery` | `{chargePercent, powerState, maximumCapacityPercent, cycleCount, timeEstimate}` | `null`; individual unavailable fields are `null` |
| `battery.powerState` | `charging`, `full`, `onBattery`, or `externalPower` | `null` |
| `battery.timeEstimate` | `{kind: untilFull\|untilEmpty, minutes}` | `null` |
| `temperatures` | `[{component, celsius, sensorIDs}]`; also holds battery temperature when readable | `[]` |

Byte fields and rates retain their existing raw bytes/B/s units; percentages use 0–100 and temperatures use °C. Optional hardware absence does not populate diagnostic errors or make the command fail. Existing core-metric failures remain independent and still produce errors/nonzero exit status after remaining samples complete.

## Validation boundary

The capacity/Foundation and same-time `statfs` comparison, M4 GPU probe, and desktop power-source observations above are confirmed. Final SwiftPM tests, application builds, unified integration sampling, lifecycle checks, and English/Chinese UI screenshots are tracked in [VALIDATION.md](VALIDATION.md); they are not implied by this design document. Intel and MacBook hardware remain unverified. Synthetic fixtures can validate layout and decoder rules but cannot prove sensor availability on those machines.
