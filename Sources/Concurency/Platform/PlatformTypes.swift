// FILE_INFO_START
// PRODUCT: Real-time Object Detection App
// MODULE: Platform
// FILE: PlatformTypes.swift
// VERSION: 1.1.0
// LAST_UPDATED: 2024-03-19
// DESCRIPTION: Platform-specific type definitions
// FILE_INFO_END

// USER_STORY_START
// AS A developer
// I WANT to have consistent platform-specific type definitions
// SO THAT I can write platform-agnostic code
// USER_STORY_END

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
public typealias PlatformColor = UIColor
public typealias PlatformImage = UIImage
public typealias PlatformOrientation = UIImage.Orientation

public extension PlatformColor {
    static func color(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) -> PlatformColor {
        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }
}
#else
import AppKit
public typealias PlatformColor = NSColor
public typealias PlatformImage = NSImage

public extension PlatformColor {
    static func color(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) -> PlatformColor {
        return NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }
}

public enum PlatformOrientation: Int {
    case up = 0
    case down = 1
    case left = 2
    case right = 3
    case upMirrored = 4
    case downMirrored = 5
    case leftMirrored = 6
    case rightMirrored = 7
    
    public var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        }
    }
}
#endif 