import AppKit

/// Formatter ensuring only integer percentage values (0–100) can be entered into the text field.
final class PercentageNumberFormatter: NumberFormatter, @unchecked Sendable {

    override init() {
        super.init()
        minimum = 0
        maximum = 100
        allowsFloats = false
        maximumFractionDigits = 0
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func isPartialStringValid(
        _ partialString: String,
        newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        if partialString.isEmpty { return true }
        guard partialString.allSatisfy({ $0.isNumber }) else { return false }
        if let val = Int(partialString) {
            return val >= 0 && val <= 100
        }
        return false
    }
}
