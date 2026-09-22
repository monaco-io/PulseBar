# Single-instance and performance verification

Verified locally on 2026-09-22, macOS 27.0 (26A428), Apple Silicon. Measurements used a development build before the version bump for 1.8.1/build 16. Public release verification is recorded separately in [VALIDATION.md](VALIDATION.md).

## Changes

- A nonblocking `flock` is acquired before creating the monitor, updater, status item, or panel. All updated app copies for the same macOS user share `~/Library/Application Support/PulseBar/instance.lock`. The descriptor stays open for the GUI lifetime and closes automatically on exit/crash. The file is deliberately retained to avoid inode replacement races. Filesystem errors stop startup instead of bypassing the check.
- Duplicate launches request the existing panel and exit successfully. The notification listener starts before lock acquisition; activation requests received before UI initialization are retained. Read-only `--sample` and debug diagnostics remain independent of the GUI lock.
- Process-sampling and event-storage queues use `.workItem` autorelease frequency. Each command-line sample has its own autorelease pool. Apple's [work-item autorelease behavior](https://developer.apple.com/documentation/dispatch/dispatchqueue/autoreleasefrequency/workitem) supplies a predictable reclamation boundary for temporary Foundation objects.
- Menu bar updates coalesce synchronous publications into one update, skip unchanged images, and no longer keep a second full resource/history snapshot in `CombineLatest`.
- Hover inspection skips unused full-history summaries; network/disk series share their summary. Monitor destruction invalidates its timer and removes workspace observers.

## Single-instance checks

- All 64 tests passed, including lock contention, release/reacquisition with a persistent lock file, child-process crash recovery, filesystem failures, and symlink rejection.
- Universal arm64/x86_64 build and deep strict app signature validation passed.
- 20 simultaneous launches across `/Applications/PulseBar.app` and `~/Applications/PulseBar.app` left exactly one main process. Another 20 launches retained that PID; all duplicates exited with status 0.
- Killing the lock owner allowed a new instance to start immediately. A separate 20-way cold launch verified that the panel opened from the duplicate notification before any warm launch was sent.
- Three packaged read-only samples completed without metric errors. The 13-second debug monitor integration check exercised the real timer, background process rankings, and isolated event persistence successfully.
- Both existing installed copies were updated; their executable hashes match the built app. Original bundles and data snapshots were backed up under `artifacts/single-instance-performance/`. Saved user settings were preserved; only the normal notification cooldown timestamp changed during monitoring. All 195 pre-update event IDs were preserved in the data check.

## Measurements

All CPU percentages below refer to one CPU core, not the whole machine.

| Check | Result |
| --- | --- |
| 501 accelerated process-reader/accumulator iterations without a per-iteration autorelease pool | Footprint 5.72 → 125.55 MB on repeat run |
| Same workload with a per-iteration pool | Footprint 5.72 → 6.13 MB |
| Five full 24-hour curves, 86,402 points each: copy/append/trim | Mean 0.366 ms, p95 0.529 ms across 500 iterations |
| Five full curves: window/summary/downsampling to 720 points | Mean 3.913 ms, p95 6.004 ms |
| Installed app, background before opening panel, approximately 28 seconds at saved 2-second refresh | Mean CPU 1.37%; footprint 17.22 → 17.16 MiB |
| Installed app, 180 seconds including native panel/accessibility activity | Mean CPU 2.25%; 0.42 idle wakeups/s; footprint 16.92–93.19 MiB, ending at 89.13 MiB |

The accelerated pool comparison demonstrates temporary-object accumulation without a reclamation boundary. It is not a claim that the previous GUI leaked that amount on every sample. The interactive run includes UI initialization and framework allocations; its footprint increase must not be described as flat memory usage or proved entirely harmless by a short measurement.

## Leak audit and limits

Mach host ports and IOKit iterators/services already use deterministic cleanup. Core Foundation ownership follows the SDK annotations. Process-name caches discard absent apps, process sampling permits only one in-flight job, icon caching is limited to 128 entries, events to 200 entries/seven days, and five history curves to 24 hours (about 9.9 MiB of raw points at a one-second interval).

The old running app's `leaks` report showed 377 nodes / 18,560 bytes. Two scans of the updated app both reported **277 nodes / 13,264 bytes**, rooted in two system `NSXPCConnection` cycles for `LNDaemonApplicationInterface`, with AppIntents `LNProcessInstanceRegistryClient` callbacks. These reported cycles did not grow between scans. The scanner also reported restricted visibility because the signed application was not debuggable. This is not a zero-leak result or proof that every allocation is reachable for the right reason.

No unbounded application-owned collection, clear retain cycle, or missing Mach/IOKit release was found in the code audit. Long-history hover rendering still scans bounded arrays; the measured cost did not justify a storage rewrite in this patch. A multi-day soak, unrestricted allocation-stack analysis, and Intel hardware testing were not performed. Native accessibility inspection confirmed live overview metrics; some later interaction attempts timed out or were rejected as changed UI state, so those attempts are not counted as successful navigation checks.

Raw outputs, benchmark sources/commands, launch checks, hashes, profile samples, and both leak reports are in `artifacts/single-instance-performance/`; start with `BENCHMARKS.md`, `launch-verification.json`, `cold-reopen-verification.json`, and `app-profile-summary.json`.
