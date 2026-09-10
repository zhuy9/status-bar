// Regenerates AppIcon.appiconset's PNGs from the source logo, masking its opaque corners so the
// icon is not a black square on a light background. 0.2237 is Apple's macOS corner ratio.
//
//   swift scripts/make-app-icon.swift docs/token-usage-logo.png AIUsageMenu/Assets.xcassets/AppIcon.appiconset
//
// Contents.json is checked in and does not change; only re-run this when the logo does.
import AppKit

let source = CommandLine.arguments[1], outDir = CommandLine.arguments[2]
guard let image = NSImage(contentsOfFile: source),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { exit(1) }

for size in [16, 32, 64, 128, 256, 512, 1024] {
    let side = CGFloat(size)
    guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
    let rect = CGRect(x: 0, y: 0, width: side, height: side)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: side * 0.2237, cornerHeight: side * 0.2237, transform: nil))
    context.clip()
    context.interpolationQuality = .high
    context.draw(cg, in: rect)
    guard let out = context.makeImage(),
          let dest = CGImageDestinationCreateWithURL(
              URL(fileURLWithPath: "\(outDir)/icon_\(size).png") as CFURL, "public.png" as CFString, 1, nil) else { exit(1) }
    CGImageDestinationAddImage(dest, out, nil)
    CGImageDestinationFinalize(dest)
}
