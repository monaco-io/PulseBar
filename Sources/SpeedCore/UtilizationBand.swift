/// Display bands shared by CPU utilization and startup-volume capacity.
/// Memory uses the kernel's pressure state instead of these thresholds.
public enum UtilizationBand: Equatable {
    case normal, warning, critical

    public init?(percent: Double?) {
        guard let percent, percent.isFinite else { return nil }
        if percent > 80 { self = .critical }
        else if percent >= 60 { self = .warning }
        else { self = .normal }
    }
}
