#!/usr/bin/env swift
import AppKit

let size: CGFloat = 1024
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let image = NSImage(size: rect.size)
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

// macOS Big Sur+ icon corner (squircle approximation)
let corner: CGFloat = size * 0.2237
let clip = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)

ctx.saveGState()
clip.addClip()

// Blue gradient background (document/trustworthy feel)
let bg = NSGradient(colors: [
    NSColor(red: 0.11, green: 0.22, blue: 0.55, alpha: 1),
    NSColor(red: 0.28, green: 0.50, blue: 0.90, alpha: 1),
])!
bg.draw(in: rect, angle: 90)

// Subtle highlight at top
let gloss = NSGradient(colors: [
    NSColor(white: 1, alpha: 0.22),
    NSColor(white: 1, alpha: 0),
])!
gloss.draw(in: NSRect(x: 0, y: size * 0.55, width: size, height: size * 0.45), angle: 270)

// White document card
let docW: CGFloat = size * 0.62
let docH: CGFloat = size * 0.76
let docX = (size - docW) / 2
let docY = (size - docH) / 2 - size * 0.02
let docRect = NSRect(x: docX, y: docY, width: docW, height: docH)

// document shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 26,
              color: NSColor(white: 0, alpha: 0.30).cgColor)
let docPath = NSBezierPath(roundedRect: docRect, xRadius: 28, yRadius: 28)
NSColor.white.setFill()
docPath.fill()
ctx.restoreGState()

// "한" character
let han: NSString = "한"
let fontSize = size * 0.44
let han_font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
let han_attrs: [NSAttributedString.Key: Any] = [
    .font: han_font,
    .foregroundColor: NSColor(red: 0.10, green: 0.22, blue: 0.48, alpha: 1),
    .kern: 0,
]
let hanSize = han.size(withAttributes: han_attrs)
let hanRect = NSRect(
    x: docX + (docW - hanSize.width) / 2,
    y: docY + (docH - hanSize.height) / 2 + size * 0.02,
    width: hanSize.width,
    height: hanSize.height
)
han.draw(in: hanRect, withAttributes: han_attrs)

// Magnifying glass badge — fully inset so ring and handle fit within squircle
let gRadius: CGFloat = size * 0.115
let ringWidth: CGFloat = size * 0.038
let handleLen: CGFloat = size * 0.085
// Place center so (radius + handle) extent stays clear of squircle corner.
let gCenter = NSPoint(x: size * 0.74, y: size * 0.25)

// outer white halo
ctx.setFillColor(NSColor.white.cgColor)
ctx.addArc(center: gCenter, radius: gRadius + ringWidth * 0.7, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.fillPath()

let accent = NSColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1)

// handle (drawn first so ring overlaps it cleanly at junction)
let h1 = NSPoint(
    x: gCenter.x + gRadius * cos(-.pi / 4),
    y: gCenter.y + gRadius * sin(-.pi / 4)
)
let h2 = NSPoint(x: h1.x + handleLen * cos(-.pi / 4),
                 y: h1.y + handleLen * sin(-.pi / 4))
ctx.setStrokeColor(accent.cgColor)
ctx.setLineWidth(ringWidth * 1.1)
ctx.setLineCap(.round)
ctx.move(to: h1)
ctx.addLine(to: h2)
ctx.strokePath()

// accent ring
ctx.setStrokeColor(accent.cgColor)
ctx.setLineWidth(ringWidth)
ctx.addArc(center: gCenter, radius: gRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.strokePath()

// lens fill (slight blue tint, semi-transparent)
ctx.setFillColor(NSColor(red: 0.28, green: 0.50, blue: 0.90, alpha: 0.20).cgColor)
ctx.addArc(center: gCenter, radius: gRadius - ringWidth * 0.5, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.fillPath()

ctx.restoreGState()  // undo clip

image.unlockFocus()

// Save as PNG
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    exit(2)
}

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/appicon_1024.png"
try png.write(to: URL(fileURLWithPath: outPath))
print("Wrote: \(outPath)")
