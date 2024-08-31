import SwiftUI

enum ColorUtils {
    static let fallbackColors: [Color] = [
        Color(red: 0.984, green: 0.698, blue: 0.698, opacity: 1), // Pastel Red
        Color(red: 0.698, green: 0.874, blue: 0.984, opacity: 1), // Pastel Blue
        Color(red: 0.941, green: 0.973, blue: 0.698, opacity: 1), // Pastel Yellow
        Color(red: 0.973, green: 0.698, blue: 0.941, opacity: 1), // Pastel Purple
        Color(red: 0.698, green: 0.984, blue: 0.831, opacity: 1), // Pastel Green
        Color(red: 0.984, green: 0.831, blue: 0.698, opacity: 1), // Pastel Orange
        Color(red: 0.831, green: 0.698, blue: 0.984, opacity: 1), // Pastel Lavender
        Color(red: 0.973, green: 0.941, blue: 0.698, opacity: 1), // Pastel Lime
        Color(red: 0.984, green: 0.698, blue: 0.831, opacity: 1), // Pastel Pink
        Color(red: 0.698, green: 0.984, blue: 0.941, opacity: 1)  // Pastel Turquoise
    ]

    static func colorForApp(_ appInfo: AppInfo) -> Color {
        if let appColor = getSystemDefinedAppColor(for: appInfo.id) {
            return enhanceColor(appColor)
        }

        // Fallback to generated color if app color can't be determined
        let index = abs(appInfo.id.hash) % fallbackColors.count
        return enhanceColor(fallbackColors[index])
    }

    private static func getSystemDefinedAppColor(for bundleIdentifier: String) -> Color? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        if let avgColor = icon.averageColor() {
            return Color(nsColor: avgColor)
        }

        return nil
    }

    private static func enhanceColor(_ color: Color) -> Color {
        let uiColor = NSColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Increase saturation and brightness
        saturation = min(saturation * 1.5, 1.0)
        brightness = min(brightness * 1.2, 1.0)

        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
    }
}

extension NSImage {
    func averageColor() -> NSColor? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: nil,
                                      width: 1,
                                      height: 1,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: bitmapInfo) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        guard let pixelBuffer = context.data else {
            return nil
        }
        
        let data = pixelBuffer.assumingMemoryBound(to: UInt8.self)
        let red = Double(data[0]) / 255.0
        let green = Double(data[1]) / 255.0
        let blue = Double(data[2]) / 255.0
        
        return NSColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
    }
}
