// FILE_INFO_START
// PRODUCT: Real-time Object Detection App
// MODULE: Models
// FILE: DetectedObject.swift
// VERSION: 1.1.0
// LAST_UPDATED: 2024-03-19
// DESCRIPTION: Core data structures for object detection with platform-agnostic design
// FILE_INFO_END

// USER_STORY_START
// AS A developer
// I WANT to have strongly-typed models for detected objects
// SO THAT I can safely handle detection results and display them in the UI
// USER_STORY_END

import Foundation
import CoreGraphics
import Platform

/// Represents a detected object with UI presentation capabilities
public struct DetectedObject: Identifiable, Equatable {
    /// Unique identifier for the detected object
    public let id: UUID = UUID()
    
    /// Name or class of the detected object
    public let name: String
    
    /// Confidence score (0.0 - 1.0)
    public let confidence: Double
    
    /// Normalized bounding box in the video frame
    public let boundingBox: CGRect?
    
    /// Color for UI representation
    public let displayColor: PlatformColor
    
    /// Timestamp of detection
    public let timestamp: TimeInterval
    
    public init(
        name: String,
        confidence: Double,
        boundingBox: CGRect? = nil,
        displayColor: PlatformColor,
        timestamp: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.name = name
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.displayColor = displayColor
        self.timestamp = timestamp
    }
    
    public static func == (lhs: DetectedObject, rhs: DetectedObject) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.confidence == rhs.confidence &&
        lhs.boundingBox == rhs.boundingBox &&
        lhs.timestamp == rhs.timestamp
    }
}

/// Represents a video frame with metadata
public struct VideoFrame {
    /// Raw frame data
    public let data: Data
    
    /// Frame timestamp
    public let timestamp: TimeInterval
    
    /// Frame dimensions
    public let size: CGSize
    
    /// Frame orientation
    public let orientation: PlatformOrientation
    
    /// Optional preview image for UI
    public let previewImage: PlatformImage?
    
    public init(
        data: Data,
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        size: CGSize = .zero,
        orientation: PlatformOrientation = .up,
        previewImage: PlatformImage? = nil
    ) {
        self.data = data
        self.timestamp = timestamp
        self.size = size
        self.orientation = orientation
        self.previewImage = previewImage
    }
}

/// Error types for detection operations
public enum DetectionError: LocalizedError {
    case failed
    case invalidFrame
    case timeout
    case mainThreadViolation
    
    public var errorDescription: String? {
        switch self {
        case .failed:
            return "Object detection failed"
        case .invalidFrame:
            return "Invalid video frame format"
        case .timeout:
            return "Detection operation timed out"
        case .mainThreadViolation:
            return "UI operation attempted on background thread"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .failed:
            return "Try processing the frame again"
        case .invalidFrame:
            return "Check frame data format and integrity"
        case .timeout:
            return "Check system load and try again"
        case .mainThreadViolation:
            return "Ensure UI updates are performed on the main thread"
        }
    }
}

/// Detection result with UI presentation data
public struct DetectionResult {
    /// Detected objects
    public let objects: [DetectedObject]
    
    /// Processing time in seconds
    public let processingTime: TimeInterval
    
    /// Frame metadata
    public let frameInfo: FrameInfo
    
    public init(
        objects: [DetectedObject],
        processingTime: TimeInterval,
        frameInfo: FrameInfo
    ) {
        self.objects = objects
        self.processingTime = processingTime
        self.frameInfo = frameInfo
    }
}

/// Frame processing metadata
public struct FrameInfo {
    /// Frame timestamp
    public let timestamp: TimeInterval
    
    /// Frame dimensions
    public let size: CGSize
    
    /// Frame index in sequence
    public let sequenceIndex: Int
    
    /// Processing status
    public var status: ProcessingStatus
    
    public init(
        timestamp: TimeInterval,
        size: CGSize,
        sequenceIndex: Int,
        status: ProcessingStatus
    ) {
        self.timestamp = timestamp
        self.size = size
        self.sequenceIndex = sequenceIndex
        self.status = status
    }
}

/// Frame processing status
public enum ProcessingStatus {
    case success
    case dropped
    case error(DetectionError)
    
    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
} 