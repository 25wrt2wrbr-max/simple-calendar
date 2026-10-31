// Draws the app icon (1024×1024 PNG) without needing Xcode.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let size: CGFloat = 1024

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else {
    FileHandle.standardError.write("Could not create bitmap".data(using: .utf8)!)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let cardInset: CGFloat = 64
let cardRect = NSRect(x: cardInset, y: cardInset, width: size - cardInset * 2, height: size - cardInset * 2)
let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 176, yRadius: 176)

// Soft drop shadow
let shadow = NSShadow()
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
shadow.set()
NSColor(calibratedWhite: 1.0, alpha: 1.0).setFill()
cardPath.fill()
NSShadow().set()

// Card body
NSColor(calibratedWhite: 1.0, alpha: 1.0).setFill()
cardPath.fill()

// Header band, clipped to the card's rounded corners
NSGraphicsContext.saveGraphicsState()
cardPath.addClip()
let bandHeight = cardRect.height * 0.27
NSColor(calibratedRed: 0.96, green: 0.25, blue: 0.28, alpha: 1.0).setFill()
NSRect(x: cardRect.minX, y: cardRect.maxY - bandHeight,
       width: cardRect.width, height: bandHeight).fill()
NSGraphicsContext.restoreGraphicsState()

// Number
let baseFont = NSFont.systemFont(ofSize: 430, weight: .bold)
let descriptor = baseFont.fontDescriptor.withDesign(.rounded) ?? baseFont.fontDescriptor
let font = NSFont(descriptor: descriptor, size: 430) ?? baseFont
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.13, alpha: 1.0),
    .paragraphStyle: paragraph
]
let textRect = NSRect(x: cardRect.minX,
                      y: cardRect.minY + cardRect.height * 0.09,
                      width: cardRect.width,
                      height: cardRect.height * 0.55)
("31" as NSString).draw(in: textRect, withAttributes: attributes)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: output))
