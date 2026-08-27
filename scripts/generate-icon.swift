// Renders the Meeting Alarm app icon to a 1024×1024 PNG: a rounded-square coral→crimson
// gradient tile with a white "bell with sound waves" (the alarm ringing) on top.
// Usage: swift scripts/generate-icon.swift <output.png>
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let side: CGFloat = 1024

func color(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// The rounded-square tile, inset from the edges the way macOS icons sit, with a soft shadow.
let inset: CGFloat = 96
let tile = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
let radius = tile.width * 0.2237
let path = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)

// Shadow pass: fill solid so the tile casts a drop shadow, then clear the shadow.
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.set()
color(225, 20, 71).setFill()
path.fill()
NSGraphicsContext.restoreGraphicsState()

/// Gradient fill: warm coral (top) → crimson (bottom-right).
let gradient = NSGradient(
    colors: [color(255, 122, 94), color(233, 30, 84), color(199, 18, 74)],
    atLocations: [0, 0.6, 1],
    colorSpace: .sRGB
)!
gradient.draw(in: path, angle: -63)

// A soft highlight near the top for a little gloss.
NSGraphicsContext.saveGraphicsState()
path.addClip()
let glow = NSGradient(
    starting: NSColor.white.withAlphaComponent(0.28),
    ending: NSColor.white.withAlphaComponent(0)
)!
glow.draw(
    fromCenter: NSPoint(x: side / 2, y: tile.maxY - 40),
    radius: 0,
    toCenter: NSPoint(x: side / 2, y: tile.maxY - 40),
    radius: tile.width * 0.62,
    options: []
)
NSGraphicsContext.restoreGraphicsState()

// The bell-with-waves glyph, white, centered, with a subtle shadow for depth.
let names = ["bell.and.waves.left.and.right.fill", "bell.badge.fill", "bell.fill"]
let base = names.lazy.compactMap {
    NSImage(systemSymbolName: $0, accessibilityDescription: nil)
}.first!
let config = NSImage.SymbolConfiguration(pointSize: 512, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
let bell = base.withSymbolConfiguration(config) ?? base

let glyphBox = min(tile.width * 0.66, tile.height * 0.66)
let scale = min(glyphBox / bell.size.width, glyphBox / bell.size.height)
let gw = bell.size.width * scale
let gh = bell.size.height * scale
let glyphRect = NSRect(x: (side - gw) / 2, y: (side - gh) / 2 - 6, width: gw, height: gh)

NSGraphicsContext.saveGraphicsState()
let bellShadow = NSShadow()
bellShadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
bellShadow.shadowBlurRadius = 22
bellShadow.shadowOffset = NSSize(width: 0, height: -10)
bellShadow.set()
bell.draw(in: glyphRect, from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("failed to encode PNG\n".utf8))
    exit(1)
}

try data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
