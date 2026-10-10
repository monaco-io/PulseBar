import AppKit
import SwiftUI

/// A native stepper keeps its arrows and keyboard behavior when embedded in
/// a multi-control form row. Its label belongs to the surrounding LabeledContent.
struct NativeStepper: NSViewRepresentable {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var increment = 1.0
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSStepper {
        let stepper = NSStepper()
        stepper.target = context.coordinator
        stepper.action = #selector(Coordinator.change(_:))
        stepper.controlSize = .small
        stepper.valueWraps = false
        stepper.autorepeat = true
        return stepper
    }

    func updateNSView(_ stepper: NSStepper, context: Context) {
        context.coordinator.onChange = { value = $0 }
        stepper.minValue = range.lowerBound
        stepper.maxValue = range.upperBound
        stepper.increment = increment
        stepper.doubleValue = value
        stepper.isEnabled = isEnabled
        stepper.setAccessibilityLabel(title)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSStepper, context: Context) -> CGSize? {
        nsView.intrinsicContentSize
    }

    final class Coordinator: NSObject {
        var onChange: ((Double) -> Void)?
        @objc func change(_ sender: NSStepper) { onChange?(sender.doubleValue) }
    }
}
