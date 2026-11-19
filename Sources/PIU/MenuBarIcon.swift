import AppKit

/// Menu bar chick, with a red badge counting dev ports when there are any.
enum MenuBarIcon {
    private static let height: CGFloat = 16

    /// The chick as a template image: macOS tints it for light/dark menu bars.
    static let plain: NSImage = {
        let image: NSImage
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "svg"),
           let svg = NSImage(contentsOf: url) {
            image = svg
            image.size = NSSize(width: height * svg.size.width / svg.size.height, height: height)
        } else {
            // Fallback when running outside the .app bundle.
            image = NSImage(systemSymbolName: "bird", accessibilityDescription: "PIU")!
        }
        image.isTemplate = true
        return image
    }()

    static func image(count: Int) -> NSImage {
        guard count > 0 else { return plain }
        let chick = plain
        let label = count > 9 ? "9+" : String(count)
        let font = NSFont.systemFont(ofSize: 7.5, weight: .bold)
        let textSize = (label as NSString).size(withAttributes: [.font: font])
        let badgeHeight: CGFloat = 9
        let badgeWidth = max(badgeHeight, textSize.width + 3.5)
        let badgeX = chick.size.width - 1.5
        let size = NSSize(width: badgeX + badgeWidth, height: height + 1)

        let image = NSImage(size: size, flipped: false) { rect in
            // Not a template image (the badge is red), so tint the chick with the menu bar's text color.
            let dark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            chick.draw(in: NSRect(origin: .zero, size: chick.size))
            (dark ? NSColor.white : NSColor.black).set()
            NSRect(origin: .zero, size: chick.size).fill(using: .sourceAtop)

            let badge = NSRect(x: badgeX, y: rect.maxY - badgeHeight, width: badgeWidth, height: badgeHeight)
            let context = NSGraphicsContext.current
            context?.compositingOperation = .clear
            NSBezierPath(roundedRect: badge.insetBy(dx: -1.2, dy: -1.2),
                         xRadius: badgeHeight / 2 + 1.2, yRadius: badgeHeight / 2 + 1.2).fill()
            context?.compositingOperation = .sourceOver
            NSColor.systemRed.setFill()
            NSBezierPath(roundedRect: badge, xRadius: badgeHeight / 2, yRadius: badgeHeight / 2).fill()
            (label as NSString).draw(
                at: NSPoint(x: badge.midX - textSize.width / 2, y: badge.midY - textSize.height / 2),
                withAttributes: [.font: font, .foregroundColor: NSColor.white]
            )
            return true
        }
        image.isTemplate = false
        // Redraw on every display so light/dark menu bar changes are picked up.
        image.cacheMode = .never
        return image
    }
}
