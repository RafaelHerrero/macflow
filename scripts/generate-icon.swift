#!/usr/bin/env swift
//
// Macflow — app icon generator.
//
// Draws the icon procedurally with CoreGraphics (no external assets, no design
// tool, no dependencies — same ethos as the rest of the project) and writes one
// PNG per size into an `.iconset` directory. `scripts/build-icon.sh` then packs
// it into `Resources/AppIcon.icns` with `iconutil`.
//
// Usage:  swift scripts/generate-icon.swift <output.iconset-dir>
//
// Design: a Big Sur–style squircle with a blue→violet gradient and a white
// window-tiling glyph (one main pane + two stacked panes) — a nod to Macflow's
// job: arranging windows.

import AppKit
import CoreGraphics

// MARK: - Drawing

/// Renders the full icon into `ctx`, a `size`×`size` context (origin bottom-left).
func drawIcon(into ctx: CGContext, size S: CGFloat) {
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // ── Background squircle ────────────────────────────────────────────────
    // A small margin keeps the rounded corners from touching the canvas edge.
    let margin = S * 0.075
    let bg = CGRect(x: margin, y: margin, width: S - 2 * margin, height: S - 2 * margin)
    // Apple's continuous-corner ratio (~0.2237 of the side) reads as a squircle.
    let radius = bg.width * 0.2237
    let bgPath = CGPath(roundedRect: bg, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let space = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(red: 0.38, green: 0.56, blue: 0.99, alpha: 1.0), // top: blue
            CGColor(red: 0.40, green: 0.29, blue: 0.86, alpha: 1.0)  // bottom: violet
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: bg.minX, y: bg.maxY),
        end: CGPoint(x: bg.minX, y: bg.minY),
        options: []
    )

    // Soft diagonal sheen across the top-left for a bit of depth.
    let sheen = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.18),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        sheen,
        start: CGPoint(x: bg.minX, y: bg.maxY),
        end: CGPoint(x: bg.midX, y: bg.midY),
        options: []
    )
    ctx.restoreGState()

    // ── Window-tiling glyph ────────────────────────────────────────────────
    let region = bg.insetBy(dx: bg.width * 0.26, dy: bg.height * 0.26)
    let gap = S * 0.024
    let paneRadius = S * 0.038

    let leftW = (region.width - gap) * 0.52
    let left = CGRect(x: region.minX, y: region.minY, width: leftW, height: region.height)

    let rightX = region.minX + leftW + gap
    let rightW = region.maxX - rightX
    let halfH = (region.height - gap) / 2
    let topRight = CGRect(x: rightX, y: region.minY + halfH + gap, width: rightW, height: halfH)
    let botRight = CGRect(x: rightX, y: region.minY, width: rightW, height: halfH)

    func pane(_ r: CGRect, alpha: CGFloat) {
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: paneRadius, cornerHeight: paneRadius, transform: nil))
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: alpha))
        ctx.fillPath()
    }
    pane(left, alpha: 1.0)
    pane(topRight, alpha: 0.88)
    pane(botRight, alpha: 0.88)
}

// MARK: - Rasterize

func pngData(size: Int) -> Data {
    let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    drawIcon(into: ctx, size: CGFloat(size))
    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])!
}

// MARK: - Write iconset

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: generate-icon.swift <output.iconset-dir>\n".data(using: .utf8)!)
    exit(1)
}

let outDir = CommandLine.arguments[1]
let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// (pixel size, file name) — the names iconutil expects.
let variants: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (px, name) in variants {
    let data = pngData(size: px)
    try! data.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
}

print("Wrote \(variants.count) PNGs to \(outDir)")
