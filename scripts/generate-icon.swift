import AppKit

// Code-native vector artwork; no screenshots, account files or external image assets.
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".build/app-icon", isDirectory: true)
let iconset = output.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func rounded(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func render(_ pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "CodexPeek.Icon", code: 1)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    let scale = NSAffineTransform()
    scale.scale(by: CGFloat(pixels) / 1024)
    scale.concat()

    let base = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 200, yRadius: 200)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
    shadow.shadowBlurRadius = 20
    shadow.shadowOffset = NSSize(width: 0, height: -9)
    shadow.set()
    NSColor(calibratedRed: 0.07, green: 0.1, blue: 0.16, alpha: 1).setFill()
    base.fill()
    NSGraphicsContext.restoreGraphicsState()
    let gradient = NSGradient(starting: NSColor(calibratedRed: 0.055, green: 0.08, blue: 0.13, alpha: 1),
                              ending: NSColor(calibratedRed: 0.16, green: 0.21, blue: 0.29, alpha: 1))!
    gradient.draw(in: base, angle: 90)
    NSColor.white.withAlphaComponent(0.12).setStroke()
    base.lineWidth = 2
    base.stroke()

    rounded(NSRect(x: 210, y: 745, width: 184, height: 24), radius: 12, color: .white.withAlphaComponent(0.65))
    let mint = NSColor(calibratedRed: 0.32, green: 0.9, blue: 0.74, alpha: 1)
    let blue = NSColor(calibratedRed: 0.47, green: 0.69, blue: 1, alpha: 1)
    mint.setFill()
    NSBezierPath(ovalIn: NSRect(x: 788, y: 741, width: 32, height: 32)).fill()

    for (y, fill, color) in [(CGFloat(550), CGFloat(450), mint), (CGFloat(326), CGFloat(315), blue)] {
        rounded(NSRect(x: 210, y: y, width: 610, height: 98), radius: 49, color: .white.withAlphaComponent(0.09))
        rounded(NSRect(x: 210, y: y, width: fill, height: 98), radius: 49, color: color)
        rounded(NSRect(x: 210, y: y - 47, width: 108, height: 12), radius: 6, color: .white.withAlphaComponent(0.2))
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "CodexPeek.Icon", code: 2)
    }
    return data
}

for points in [16, 32, 128, 256, 512] {
    for density in [1, 2] {
        let name = "icon_\(points)x\(points)\(density == 2 ? "@2x" : "").png"
        try render(points * density).write(to: iconset.appendingPathComponent(name))
    }
}
try render(512).write(to: output.appendingPathComponent("AppIcon.png"))
print("Generated vector icon set")
