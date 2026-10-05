# Hardware temperatures

PulseBar shows a component only when a known, accessible hardware sensor returns a valid temperature. CPU, GPU, memory, storage, and battery are supported categories; their availability depends on the Mac and macOS version. If no category has a valid reading, the overview hides the temperature row.

Each displayed value is the highest current reading among the exposed sensors mapped to that component. It is not an average, a complete inventory of all sensors, or a temperature inferred from CPU usage, memory pressure, or the system thermal state. Some mapped sensors measure proximity rather than a die; the component label does not imply that every Mac exposes a die sensor.

## Source and compatibility

The reader makes read-only AppleSMC user-client requests through IOKit. This interface and its sensor keys vary across hardware; access is not guaranteed. PulseBar uses a bounded catalog with explicit component mappings, informed by the [Stats sensor catalog](https://github.com/exelban/stats/blob/master/Modules/Sensors/values.swift) and [VirtualSMC sensor-key documentation](https://github.com/acidanthera/VirtualSMC/blob/master/Docs/SMCSensorKeys.txt). The generation-specific mappings are in [TemperatureSensors.swift](../Sources/SpeedCore/TemperatureSensors.swift). Unknown temperature-like keys and generic PMU sensors are excluded rather than assigned to a guessed component.

| Platform | Expected sensor scope |
| --- | --- |
| Apple Silicon M1–M5 | Generation-specific CPU/GPU keys, plus known storage and battery keys when exposed. Memory keys are mapped for M1; M2–M5 memory temperatures are omitted because a reliable mapping has not been established. |
| Unrecognized Apple Silicon generation | No guessed CPU/GPU/memory mapping. Only the common, known storage and battery keys are probed. |
| Intel | Known CPU/GPU die or proximity keys, memory die/riser keys, storage sensors, and battery sensors when exposed. Intel hardware has not been tested for this release. |

Read-only probes on the development M4 iMac (`Mac16,2`) returned CPU, GPU, and storage temperatures without administrator access. They did not expose an accepted memory or battery reading. This does not establish availability on other Macs; a missing component is expected behavior.

## Validity and sampling

Supported encodings are signed big-endian `sp78` with exactly two bytes and little-endian IEEE 754 `flt ` with exactly four bytes. A reading must be finite and between 10 and 125 °C, inclusive. This range is a plausibility filter for sensor data, not an Apple operating or safety threshold. Zero, malformed payloads, unsupported types, read failures, and values outside that range are omitted.

Panel temperature reads run on a dedicated serial background queue at most once every 5 seconds. A longer configured refresh interval also applies. The reader caches known sensor metadata to limit repeated queries; it does not enumerate arbitrary SMC keys or launch periodic command-line tools. Failed reads clear the corresponding value. If the service cannot be opened or discovery finds no supported sensors, the reader releases the connection and waits at least 60 seconds before attempting discovery again. If every read from previously discovered sensors fails, it releases the connection and waits at least 5 seconds before reopening. Read attempts during these waits return no temperatures.

The `--sample` diagnostic attempts temperature reads at its own `--interval`, subject to the same failure retry delays. It emits `temperatures: [{component, celsius, sensorIDs}]`, or an empty array when none are available. The panel's 5-second minimum is not imposed on diagnostic samples.

The app does not install a privileged helper, request administrator access, or change system security settings. If AppleSMC is missing, inaccessible, or exposes no supported sensors, temperature readings stay hidden while CPU usage, memory, disk, and network monitoring continue.
