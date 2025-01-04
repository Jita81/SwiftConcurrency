import Foundation
import CoreGraphics

public struct DetectedObject: Identifiable, Equatable {
    public let id: UUID = UUID()
    public let name: String
    public let confidence: Double
    public let boundingBox: CGRect?
    
    public init(name: String, confidence: Double, boundingBox: CGRect? = nil) {
        self.name = name
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

public struct VideoFrame {
    public let data: Data
    public let timestamp: TimeInterval
    public let size: CGSize
    
    public init(data: Data, timestamp: TimeInterval = Date().timeIntervalSince1970, size: CGSize = .zero) {
        self.data = data
        self.timestamp = timestamp
        self.size = size
    }
}

public enum DetectionError: Error {
    case failed
    case invalidFrame
    case timeout
} 