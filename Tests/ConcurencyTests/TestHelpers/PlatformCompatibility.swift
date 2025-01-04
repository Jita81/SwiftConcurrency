#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage
#endif

import CoreGraphics

struct TestPlatformColor {
    static func color(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) -> PlatformColor {
        #if canImport(UIKit)
        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        #else
        return NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        #endif
    }
}

struct TestPlatformImage {
    static func emptyImage() -> PlatformImage {
        #if canImport(UIKit)
        return UIImage()
        #else
        return NSImage()
        #endif
    }
} 