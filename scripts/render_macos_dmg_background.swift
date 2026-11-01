import AppKit
import Foundation

// Run after editing the vector artwork:
// swift scripts/render_macos_dmg_background.swift
// Optional arguments: <source-svg> <output-png>.
let source = CommandLine.arguments.count > 1
  ? CommandLine.arguments[1] : "installer/macos/dmg-background.svg"
let output = CommandLine.arguments.count > 2
  ? CommandLine.arguments[2] : "installer/macos/dmg-background.png"

guard let image = NSImage(contentsOfFile: source), image.isValid else {
  fatalError("Cannot read the DMG background SVG: \(source)")
}
let width = Int(image.size.width)
let height = Int(image.size.height)
guard width > 0, height > 0, width <= 8192, height <= 8192,
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32
  ), let context = NSGraphicsContext(bitmapImageRep: bitmap)
else {
  fatalError("Cannot allocate the DMG background canvas.")
}

// One PNG pixel is one Finder point (72 DPI), keeping the icon locations
// aligned with the original 720 x 440 artwork on Retina displays too.
bitmap.size = NSSize(width: width, height: height)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
  fatalError("Cannot encode the DMG background PNG.")
}
try png.write(to: URL(fileURLWithPath: output), options: .atomic)
print("Rendered \(width) x \(height) DMG background at 72 DPI: \(output)")
