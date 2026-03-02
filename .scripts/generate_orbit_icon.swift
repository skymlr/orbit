import AppKit
import Foundation

private let canvasSize: CGFloat = 1024
private let cornerRadius: CGFloat = 224

private func makeImage() -> NSImage {
    let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
    let roundedPath = CGPath(
        roundedRect: rect.insetBy(dx: 32, dy: 32),
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )

    ctx.saveGState()
    ctx.addPath(roundedPath)
    ctx.clip()

    let bgColors = [
        NSColor(calibratedRed: 0.04, green: 0.09, blue: 0.16, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.06, green: 0.14, blue: 0.24, alpha: 1).cgColor,
    ] as CFArray

    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.maxY),
            end: CGPoint(x: rect.midX, y: rect.minY),
            options: []
        )
    }

    drawStars(in: ctx, count: 28, in: rect)
    drawOrbitMotif(in: ctx, rect: rect)

    ctx.restoreGState()

    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.2).cgColor)
    ctx.setLineWidth(2)
    ctx.addPath(roundedPath)
    ctx.strokePath()

    return image
}

private func drawStars(in ctx: CGContext, count: Int, in rect: CGRect) {
    for i in 0..<count {
        let seed = CGFloat((i * 67) % 997) / 997
        let x = rect.minX + 90 + ((rect.width - 180) * seed)
        let ySeed = CGFloat((i * 139) % 941) / 941
        let y = rect.minY + 90 + ((rect.height - 180) * ySeed)
        let size = CGFloat(1.4) + CGFloat((i * 17) % 3)

        let alpha = 0.22 + CGFloat((i * 29) % 35) / 100
        ctx.setFillColor(NSColor.white.withAlphaComponent(alpha).cgColor)
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
    }
}

private func drawOrbitMotif(in ctx: CGContext, rect: CGRect) {
    let center = CGPoint(x: rect.midX, y: rect.midY)

    let orbitRadii: [CGFloat] = [116, 188, 260, 332]
    for (index, radius) in orbitRadii.enumerated() {
        let alpha = 0.28 + CGFloat(index) * 0.08
        ctx.setStrokeColor(NSColor(calibratedRed: 0.58, green: 0.84, blue: 0.95, alpha: alpha).cgColor)
        ctx.setLineWidth(4)
        ctx.strokeEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }

    let sunRadius: CGFloat = 72
    ctx.setFillColor(NSColor(calibratedRed: 0.98, green: 0.75, blue: 0.30, alpha: 1).cgColor)
    ctx.fillEllipse(in: CGRect(
        x: center.x - sunRadius,
        y: center.y - sunRadius,
        width: sunRadius * 2,
        height: sunRadius * 2
    ))

    ctx.setFillColor(NSColor.white.withAlphaComponent(0.28).cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - 22, y: center.y + 18, width: 24, height: 24))

    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.16).cgColor)
    ctx.setLineWidth(2)
    ctx.strokeEllipse(in: CGRect(x: center.x - 76, y: center.y - 76, width: 152, height: 152))

    let planets: [(radius: CGFloat, angle: CGFloat, size: CGFloat, color: NSColor)] = [
        (116, 24, 18, NSColor(calibratedRed: 0.65, green: 0.86, blue: 0.96, alpha: 1)),
        (188, 205, 24, NSColor(calibratedRed: 0.97, green: 0.71, blue: 0.44, alpha: 1)),
        (260, 302, 26, NSColor(calibratedRed: 0.60, green: 0.74, blue: 0.92, alpha: 1)),
        (332, 132, 30, NSColor(calibratedRed: 0.90, green: 0.54, blue: 0.34, alpha: 1)),
    ]

    for planet in planets {
        let point = pointOnCircle(center: center, radius: planet.radius, angleDegrees: planet.angle)
        ctx.setFillColor(planet.color.cgColor)
        ctx.fillEllipse(in: CGRect(
            x: point.x - planet.size / 2,
            y: point.y - planet.size / 2,
            width: planet.size,
            height: planet.size
        ))
    }

    let moonCenter = pointOnCircle(center: center, radius: 332, angleDegrees: 166)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.86).cgColor)
    ctx.fillEllipse(in: CGRect(x: moonCenter.x - 6, y: moonCenter.y - 6, width: 12, height: 12))
}

private func pointOnCircle(center: CGPoint, radius: CGFloat, angleDegrees: CGFloat) -> CGPoint {
    let radians = angleDegrees * (.pi / 180)
    return CGPoint(
        x: center.x + cos(radians) * radius,
        y: center.y + sin(radians) * radius
    )
}

private func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "OrbitIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
    }
    try png.write(to: url)
}

private func scaleAndSave(baseURL: URL, outputURL: URL, size: Int) throws {
    guard let source = NSImage(contentsOf: baseURL) else {
        throw NSError(domain: "OrbitIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load base icon"])
    }
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    source.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: NSRect(x: 0, y: 0, width: source.size.width, height: source.size.height),
        operation: .copy,
        fraction: 1
    )
    image.unlockFocus()
    try savePNG(image, to: outputURL)
}

private func writeContentsJSON(to appIconSetURL: URL) throws {
    let json = """
    {
      "images" : [
        { "idiom" : "mac", "size" : "16x16", "scale" : "1x", "filename" : "icon_16x16.png" },
        { "idiom" : "mac", "size" : "16x16", "scale" : "2x", "filename" : "icon_16x16@2x.png" },
        { "idiom" : "mac", "size" : "32x32", "scale" : "1x", "filename" : "icon_32x32.png" },
        { "idiom" : "mac", "size" : "32x32", "scale" : "2x", "filename" : "icon_32x32@2x.png" },
        { "idiom" : "mac", "size" : "128x128", "scale" : "1x", "filename" : "icon_128x128.png" },
        { "idiom" : "mac", "size" : "128x128", "scale" : "2x", "filename" : "icon_128x128@2x.png" },
        { "idiom" : "mac", "size" : "256x256", "scale" : "1x", "filename" : "icon_256x256.png" },
        { "idiom" : "mac", "size" : "256x256", "scale" : "2x", "filename" : "icon_256x256@2x.png" },
        { "idiom" : "mac", "size" : "512x512", "scale" : "1x", "filename" : "icon_512x512.png" },
        { "idiom" : "mac", "size" : "512x512", "scale" : "2x", "filename" : "icon_512x512@2x.png" }
      ],
      "info" : {
        "version" : 1,
        "author" : "xcode"
      }
    }
    """
    try json.data(using: .utf8)?.write(to: appIconSetURL.appendingPathComponent("Contents.json"))
}

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let outputRoot = root.appendingPathComponent("Design/AppIcon")
let appIconSetURL = outputRoot.appendingPathComponent("AppIcon.appiconset")

try fileManager.createDirectory(at: appIconSetURL, withIntermediateDirectories: true)

let baseURL = outputRoot.appendingPathComponent("OrbitIcon-1024.png")
let baseImage = makeImage()
try savePNG(baseImage, to: baseURL)

let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, size) in outputs {
    try scaleAndSave(baseURL: baseURL, outputURL: appIconSetURL.appendingPathComponent(name), size: size)
}

try writeContentsJSON(to: appIconSetURL)
print("Generated icon assets in \(outputRoot.path)")
