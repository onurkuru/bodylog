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
}
