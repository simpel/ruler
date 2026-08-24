import AppKit

/// The Help window: one scrollable sheet listing every gesture and option.
/// Rebuilt each time it is shown, so it reflects the current settings.
final class HelpWindowController {

    static let shared = HelpWindowController()

    private var window: NSWindow?
    private let textView = NSTextView()

    private init() {}

    func show() {
        if window == nil { window = makeWindow() }
        textView.textStorage?.setAttributedString(makeContent())
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))

        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = "Ruler Help"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 380, height: 320)
        window.level = .normal

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 20, height: 18)
        textView.autoresizingMask = [.width]

        let scroll = NSScrollView(frame: window.contentLayoutRect)
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        scroll.autoresizingMask = [.width, .height]
        window.contentView = scroll
        return window
    }

    // MARK: - Content

    private func makeContent() -> NSAttributedString {
        let gesture = Settings.shared.measureModifier
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        let out = NSMutableAttributedString()
        out.append(title("Ruler \(version)"))
        out.append(body("A screen ruler that floats above every other window. It lives in the menu bar — there is no Dock icon and no main window.\n"))

        out.append(heading("The rulers"))
        out.append(items([
            ("Drag a ruler", "move it anywhere on screen"),
            ("Drag the far end", "change its length — the end with the grip dots"),
            ("Double-click a ruler", "set its zero mark at that spot"),
            ("Right-click a ruler", "set or reset zero, add a cross guide, hide the ruler"),
            ("Move the pointer", "a red line and a pixel readout follow it on both rulers"),
        ]))

        out.append(heading("Measuring — \(gesture.title.lowercased())"))
        out.append(body("Hold the modifier to see the pointer's X and Y. Keep holding it and drag: Ruler draws the line between press and release with the distance in pixels plus the width and height of the drag, and both rulers highlight the span you covered.\n"))
        out.append(items([
            ("Measurements stay", "letting go of the mouse leaves the measurement on screen, so you can measure several things at once"),
            ("Dismiss one", "click the ✕ on its readout badge"),
            ("Dismiss all", "Clear All Measurements in the menu"),
        ]))
        out.append(items([
            ("Change the gesture", "Measure Gesture in the menu — shift, ⇧⌘ or ⌥⌘"),
            ("Note", "Ruler never swallows clicks, so the app under the pointer also receives the drag. Switch to ⌥⌘ if that gets in the way."),
        ]))

        out.append(heading("Marklines and guides"))
        out.append(items([
            ("Crosshair", "two screen-wide hairlines follow the pointer — toggle with Crosshair Follows Pointer"),
            ("⌥-drag off a ruler", "pull out a fixed amber guide, running parallel to that ruler"),
            ("Right-click a ruler", "Add Cross Guide Here — a guide crossing it at the clicked value"),
            ("Drag a guide", "move it; its badge sits at the screen edge and shows its position on the matching ruler"),
            ("Hover or drag a guide", "shows its distance to every other guide, one dimension row per pair along the screen edge"),
            ("Double-click a guide", "remove it — or right-click it for remove / clear all"),
            ("Guides menu", "add a guide at the pointer, or clear every guide"),
        ]))
        out.append(body("Guides are remembered between launches.\n"))

        out.append(heading("Units, look and layout"))
        out.append(items([
            ("Units", "Points are the logical pixels CSS and design tools use. Device Pixels are physical Retina pixels — twice as many on this display."),
            ("Opacity", "100% down to 30%"),
            ("Click-Through", "rulers and guides stop taking clicks, so you can work underneath them. The lines keep tracking, but you cannot drag them until you switch it off."),
            ("Reset Position & Size", "lays the rulers out as an L so both zero marks sit on exactly the same pixel"),
            ("Reset Zero Marks", "puts both zeros back at the ruler ends"),
        ]))

        out.append(heading("Good to know"))
        out.append(items([
            ("No permissions", "pointer, buttons and modifiers are polled 60 times a second rather than tapped, so Ruler needs no accessibility or screen-recording access."),
            ("Always on top", "the rulers join every Space and stay above full-screen windows."),
            ("Launch at Login", "toggle it in the menu — macOS starts Ruler with your session."),
            ("Quit", "Quit Ruler in the menu, or ⌘Q while the menu is open."),
        ]))
        return out
    }

    // MARK: - Text styling

    private func title(_ text: String) -> NSAttributedString {
        let p = NSMutableParagraphStyle()
        p.paragraphSpacing = 6
        return NSAttributedString(string: text + "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: p,
        ])
    }

    private func heading(_ text: String) -> NSAttributedString {
        let p = NSMutableParagraphStyle()
        p.paragraphSpacingBefore = 18
        p.paragraphSpacing = 6
        return NSAttributedString(string: text + "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: p,
        ])
    }

    private func body(_ text: String) -> NSAttributedString {
        let p = NSMutableParagraphStyle()
        p.paragraphSpacing = 4
        p.lineSpacing = 2
        return NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: p,
        ])
    }

    /// Rows of "gesture — what it does", hanging-indented so wrapped lines line up.
    private func items(_ rows: [(String, String)]) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let p = NSMutableParagraphStyle()
        p.headIndent = 14
        p.firstLineHeadIndent = 0
        p.paragraphSpacing = 5
        p.lineSpacing = 2

        for (term, definition) in rows {
            let line = NSMutableAttributedString(string: term, attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: p,
            ])
            line.append(NSAttributedString(string: "  —  " + definition + "\n", attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: p,
            ]))
            out.append(line)
        }
        return out
    }
}
