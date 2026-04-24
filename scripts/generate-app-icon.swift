import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetsURL = root.appendingPathComponent("Assets", isDirectory: true)
let iconsetURL = assetsURL.appendingPathComponent("BubblePath.iconset", isDirectory: true)
let icnsURL = assetsURL.appendingPathComponent("BubblePath.icns")

try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: iconsetURL)
try? FileManager.default.removeItem(at: icnsURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct BubbleSpec {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let color: NSColor
    let alpha: CGFloat
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current?.cgContext else { return image }
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.22
    let appShape = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.035, dy: size * 0.035), xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    appShape.addClip()

    let background = NSGradient(colors: [
        NSColor(calibratedRed: 0.05, green: 0.14, blue: 0.22, alpha: 1),
        NSColor(calibratedRed: 0.07, green: 0.34, blue: 0.42, alpha: 1),
        NSColor(calibratedRed: 0.42, green: 0.78, blue: 0.86, alpha: 1)
    ])
    background?.draw(in: rect, angle: 48)

    let glowColors = [
        NSColor(calibratedRed: 0.72, green: 0.96, blue: 1.0, alpha: 0.34).cgColor,
        NSColor(calibratedRed: 0.72, green: 0.96, blue: 1.0, alpha: 0.0).cgColor
    ] as CFArray
    if let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0, 1]) {
        context.drawRadialGradient(
            glow,
            startCenter: CGPoint(x: size * 0.66, y: size * 0.70),
            startRadius: 0,
            endCenter: CGPoint(x: size * 0.66, y: size * 0.70),
            endRadius: size * 0.56,
            options: [.drawsAfterEndLocation]
        )
    }

    let currentPath = NSBezierPath()
    currentPath.move(to: CGPoint(x: size * 0.12, y: size * 0.32))
    currentPath.curve(
        to: CGPoint(x: size * 0.86, y: size * 0.76),
        controlPoint1: CGPoint(x: size * 0.20, y: size * 0.80),
        controlPoint2: CGPoint(x: size * 0.62, y: size * 0.18)
    )
    NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 0.14).setStroke()
    currentPath.lineCapStyle = .round
    currentPath.lineWidth = max(2, size * 0.022)
    currentPath.stroke()

    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedWhite: 0, alpha: 0.24).setStroke()
    appShape.lineWidth = max(1, size * 0.018)
    appShape.stroke()

    let bubbles = [
        BubbleSpec(x: 0.34, y: 0.36, radius: 0.13, color: NSColor(calibratedRed: 0.98, green: 0.81, blue: 0.56, alpha: 1), alpha: 0.84),
        BubbleSpec(x: 0.47, y: 0.63, radius: 0.22, color: NSColor(calibratedRed: 0.92, green: 0.98, blue: 1.00, alpha: 1), alpha: 0.82),
        BubbleSpec(x: 0.72, y: 0.54, radius: 0.15, color: NSColor(calibratedRed: 0.73, green: 0.96, blue: 1.00, alpha: 1), alpha: 0.78),
        BubbleSpec(x: 0.78, y: 0.78, radius: 0.08, color: NSColor(calibratedRed: 0.98, green: 0.72, blue: 0.86, alpha: 1), alpha: 0.78)
    ]

    let line = NSBezierPath()
    line.move(to: CGPoint(x: bubbles[0].x * size, y: bubbles[0].y * size))
    line.curve(
        to: CGPoint(x: bubbles[1].x * size, y: bubbles[1].y * size),
        controlPoint1: CGPoint(x: size * 0.32, y: size * 0.49),
        controlPoint2: CGPoint(x: size * 0.39, y: size * 0.59)
    )
    line.move(to: CGPoint(x: bubbles[1].x * size, y: bubbles[1].y * size))
    line.curve(
        to: CGPoint(x: bubbles[2].x * size, y: bubbles[2].y * size),
        controlPoint1: CGPoint(x: size * 0.55, y: size * 0.70),
        controlPoint2: CGPoint(x: size * 0.66, y: size * 0.63)
    )
    line.move(to: CGPoint(x: bubbles[2].x * size, y: bubbles[2].y * size))
    line.curve(
        to: CGPoint(x: bubbles[3].x * size, y: bubbles[3].y * size),
        controlPoint1: CGPoint(x: size * 0.77, y: size * 0.60),
        controlPoint2: CGPoint(x: size * 0.82, y: size * 0.70)
    )
    NSColor(calibratedRed: 0.95, green: 0.99, blue: 1.0, alpha: 0.62).setStroke()
    line.lineCapStyle = .round
    line.lineJoinStyle = .round
    line.lineWidth = max(2, size * 0.024)
    line.stroke()

    for bubble in bubbles {
        let center = CGPoint(x: bubble.x * size, y: bubble.y * size)
        let diameter = bubble.radius * size
        let bubbleRect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        let path = NSBezierPath(ovalIn: bubbleRect)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowBlurRadius = size * 0.045
        shadow.shadowOffset = CGSize(width: 0, height: -size * 0.015)
        shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.28)
        shadow.set()
        bubble.color.withAlphaComponent(bubble.alpha).setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()

        let highlight = NSBezierPath(ovalIn: bubbleRect.insetBy(dx: diameter * 0.22, dy: diameter * 0.22).offsetBy(dx: -diameter * 0.12, dy: diameter * 0.12))
        NSColor(calibratedWhite: 1, alpha: 0.34).setFill()
        highlight.fill()

        NSColor(calibratedWhite: 1, alpha: 0.56).setStroke()
        path.lineWidth = max(1, size * 0.007)
        path.stroke()
    }

    let focusRing = NSBezierPath(ovalIn: CGRect(
        x: size * 0.27,
        y: size * 0.43,
        width: size * 0.40,
        height: size * 0.40
    ))
    NSColor(calibratedRed: 0.86, green: 0.98, blue: 1.0, alpha: 0.22).setStroke()
    focusRing.lineWidth = max(2, size * 0.012)
    focusRing.stroke()

    return image
}

func savePNG(size: CGFloat, filename: String) throws {
    let image = drawIcon(size: size)
    guard let tiffData = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiffData),
          let pngData = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "BubblePathIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render \(filename)."])
    }

    try pngData.write(to: iconsetURL.appendingPathComponent(filename), options: [.atomic])
}

let icons: [(CGFloat, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for icon in icons {
    try savePNG(size: icon.0, filename: icon.1)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "BubblePathIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed."])
}

print("Generated \(icnsURL.path)")
