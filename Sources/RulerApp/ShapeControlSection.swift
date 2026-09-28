import AppKit

private final class ShapeSegmentedControl: NSSegmentedControl {
    var onSegmentTapped: ((Int) -> Void)?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        onSegmentTapped?(selectedSegment)
    }
}

/// Control panel toggle for choosing live shape drawing modes (Rectangle vs Circle).
final class ShapeControlSection: NSView {

    private let universalFontSize: CGFloat = 12

    // Draw mode selector (toggles between Rectangle, Circle, and Line)
    private let segmentedControl = ShapeSegmentedControl(labels: ["Rectangle", "Circle", "Line"],
                                                         trackingMode: .selectOne,
                                                         target: nil,
                                                         action: nil)

    private var isSyncing = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        appearance = NSAppearance(named: .darkAqua)
        setupUI()
        bindActions()
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    private func setupUI() {
        segmentedControl.appearance = NSAppearance(named: .darkAqua)
        segmentedControl.segmentDistribution = .fillEqually
        segmentedControl.controlSize = .regular
        segmentedControl.font = NSFont.systemFont(ofSize: universalFontSize, weight: .medium)
        segmentedControl.setToolTip("Rectangle measurement mode (click to draw)", forSegment: 0)
        segmentedControl.setToolTip("Circle measurement mode (click to draw)", forSegment: 1)
        segmentedControl.setToolTip("Line measurement mode (click to draw)", forSegment: 2)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: topAnchor),
            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor),
            segmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func bindActions() {
        segmentedControl.onSegmentTapped = { [weak self] segment in
            self?.selectShape(segment: segment)
        }
        segmentedControl.target = self
        segmentedControl.action = #selector(onToggleShape)
    }

    private func selectShape(segment: Int) {
        switch segment {
        case 1:
            Settings.shared.drawShapeType = .circle
        case 2:
            Settings.shared.drawShapeType = .line
        default:
            Settings.shared.drawShapeType = .rectangle
        }
        RulerController.shared.activateContext()
    }

    func syncWithSettings() {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        switch Settings.shared.drawShapeType {
        case .rectangle:
            segmentedControl.selectedSegment = 0
        case .circle:
            segmentedControl.selectedSegment = 1
        case .line:
            segmentedControl.selectedSegment = 2
        }
    }

    @objc private func onToggleShape() {
        selectShape(segment: segmentedControl.selectedSegment)
    }
}
