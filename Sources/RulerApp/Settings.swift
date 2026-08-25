import AppKit

enum RulerAxis {
    case horizontal
    case vertical
}

/// Modifier combination that arms the click-and-drag measuring gesture.
enum MeasureModifier: Int, CaseIterable {
    case shift = 0
    case shiftCommand = 1
    case optionCommand = 2

    var flags: NSEvent.ModifierFlags {
        switch self {
        case .shift: return [.shift]
        case .shiftCommand: return [.shift, .command]
        case .optionCommand: return [.option, .command]
        }
    }

    var title: String {
        switch self {
        case .shift: return "Shift-Drag"
        case .shiftCommand: return "Shift-Command-Drag"
        case .optionCommand: return "Option-Command-Drag"
        }
    }

    /// True when exactly this combination is held (ignoring caps lock etc.).
    func matches(_ held: NSEvent.ModifierFlags) -> Bool {
        let relevant: NSEvent.ModifierFlags = [.shift, .control, .option, .command]
        return held.intersection(relevant) == flags
    }
}

extension Notification.Name {
    static let rulerSettingsChanged = Notification.Name("RulerSettingsChanged")
}

/// User-visible options, persisted in UserDefaults.
final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    private init() {
        migrateLegacyDomain()
        defaults.register(defaults: [
            Key.showHorizontal: true,
            Key.showVertical: true,
            Key.devicePixels: false,
            Key.opacity: 1.0,
            Key.clickThrough: false,
            Key.crosshair: true,
            Key.measureModifier: 0,
        ])
    }

    private enum Key {
        static let showHorizontal = "showHorizontal"
        static let showVertical = "showVertical"
        static let devicePixels = "devicePixels"
        static let opacity = "opacity"
        static let clickThrough = "clickThrough"
        static let crosshair = "crosshair"
        static let measureModifier = "measureModifier"
        static let guides = "guides"
        static let frame = "frame."
        static let zero = "zero."
    }

    var showHorizontal: Bool {
        get { defaults.bool(forKey: Key.showHorizontal) }
        set { defaults.set(newValue, forKey: Key.showHorizontal); changed() }
    }

    var showVertical: Bool {
        get { defaults.bool(forKey: Key.showVertical) }
        set { defaults.set(newValue, forKey: Key.showVertical); changed() }
    }

    /// When true, readouts are in physical device pixels (2× on Retina)
    /// instead of logical points (what CSS/design tools call pixels).
    var devicePixels: Bool {
        get { defaults.bool(forKey: Key.devicePixels) }
        set { defaults.set(newValue, forKey: Key.devicePixels); changed() }
    }

    /// The bundle identifier has changed twice since Ruler first shipped;
    /// bring settings from every prior domain along on first launch, most
    /// recent first, so nothing is lost across an update.
    private func migrateLegacyDomain() {
        let flag = "migratedLegacyDomain"
        guard !defaults.bool(forKey: flag) else { return }
        defaults.set(true, forKey: flag)

        let legacyDomains = ["com.github.simpel.ruler", "local.joelsanden.RulerApp"]
        let keys = [Key.showHorizontal, Key.showVertical, Key.devicePixels,
                    Key.opacity, Key.clickThrough, Key.crosshair,
                    Key.measureModifier, Key.guides,
                    Key.frame + "h", Key.frame + "v", Key.zero + "h", Key.zero + "v"]

        for domain in legacyDomains {
            guard let legacy = UserDefaults(suiteName: domain) else { continue }
            for key in keys where defaults.object(forKey: key) == nil {
                if let value = legacy.object(forKey: key) {
                    defaults.set(value, forKey: key)
                }
            }
        }
    }

    var opacity: Double {
        get { defaults.double(forKey: Key.opacity) }
        set { defaults.set(newValue, forKey: Key.opacity); changed() }
    }

    var clickThrough: Bool {
        get { defaults.bool(forKey: Key.clickThrough) }
        set { defaults.set(newValue, forKey: Key.clickThrough); changed() }
    }

    /// Full-screen hairlines that follow the pointer.
    var crosshairEnabled: Bool {
        get { defaults.bool(forKey: Key.crosshair) }
        set { defaults.set(newValue, forKey: Key.crosshair); changed() }
    }

    var measureModifier: MeasureModifier {
        get { MeasureModifier(rawValue: defaults.integer(forKey: Key.measureModifier)) ?? .shift }
        set { defaults.set(newValue.rawValue, forKey: Key.measureModifier); changed() }
    }

    /// Fixed guides, encoded as "h|x|y".
    var savedGuides: [String] {
        get { defaults.stringArray(forKey: Key.guides) ?? [] }
        set { defaults.set(newValue, forKey: Key.guides) }
    }

    // MARK: - Per-ruler geometry

    func savedFrame(for axis: RulerAxis) -> NSRect? {
        guard let s = defaults.string(forKey: Key.frame + axisKey(axis)) else { return nil }
        let r = NSRectFromString(s)
        return r.width > 1 && r.height > 1 ? r : nil
    }

    func setSavedFrame(_ frame: NSRect, for axis: RulerAxis) {
        defaults.set(NSStringFromRect(frame), forKey: Key.frame + axisKey(axis))
    }

    /// Distance in points from the ruler's start to its zero mark.
    func zeroOffset(for axis: RulerAxis) -> CGFloat {
        CGFloat(defaults.double(forKey: Key.zero + axisKey(axis)))
    }

    func setZeroOffset(_ value: CGFloat, for axis: RulerAxis) {
        defaults.set(Double(value), forKey: Key.zero + axisKey(axis))
    }

    private func axisKey(_ axis: RulerAxis) -> String {
        axis == .horizontal ? "h" : "v"
    }

    private func changed() {
        NotificationCenter.default.post(name: .rulerSettingsChanged, object: nil)
    }
}
