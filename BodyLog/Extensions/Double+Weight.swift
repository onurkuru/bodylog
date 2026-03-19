import Foundation

extension Double {
    /// Convert kg to lbs
    var toLbs: Double {
        self * 2.20462
    }

    /// Convert lbs to kg
    var toKg: Double {
        self / 2.20462
    }

    /// Display weight in the given unit, formatted to 1 decimal place
    func formatted(unit: WeightUnit) -> String {
        let value = unit == .lbs ? self.toLbs : self
        return String(format: "%.1f", value)
    }

    /// Display weight with unit label (e.g. "72.4 kg")
    func formattedWithUnit(_ unit: WeightUnit) -> String {
        "\(formatted(unit: unit)) \(unit.rawValue)"
    }

    /// Split a kg value into picker components for the given display unit
    func toPickerComponents(unit: WeightUnit) -> (whole: Int, decimal: Int) {
        let display = unit == .lbs ? self.toLbs : self
        let tenths = Int((display * 10).rounded())
        return (tenths / 10, tenths % 10)
    }

    /// Reassemble picker components back into kg
    static func fromPicker(whole: Int, decimal: Int, unit: WeightUnit) -> Double {
        let display = Double(whole) + Double(decimal) / 10.0
        return unit == .lbs ? display.toKg : display
    }

    /// Format with sign prefix (e.g. "+2.3" or "-1.5")
    func formattedWithSign(unit: WeightUnit) -> String {
        let text = formatted(unit: unit)
        return self > 0 ? "+\(text)" : text
    }
}
