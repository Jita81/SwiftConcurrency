"""
#FILE_INFO_START
PRODUCT: Real-time Object Detection App
MODULE: Models
FILE: DetectedObject.swift
VERSION: 1.0.0
LAST_UPDATED: 2024-03-19
DESCRIPTION: Core data structures for object detection
#FILE_INFO_END

#USER_STORY_START
AS A developer
I WANT to have strongly-typed models for detected objects
SO THAT I can safely handle detection results throughout the app
#USER_STORY_END
"""

import Foundation

struct DetectedObject: Identifiable, Equatable {
    let id: UUID = UUID()
    let name: String
    let confidence: Double
    let boundingBox: CGRect?
    
    init(name: String, confidence: Double, boundingBox: CGRect? = nil) {
        self.name = name
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

struct VideoFrame {
    let data: Data
    let timestamp: TimeInterval
    let size: CGSize
    
    init(data: Data, timestamp: TimeInterval = Date().timeIntervalSince1970, size: CGSize = .zero) {
        self.data = data
        self.timestamp = timestamp
        self.size = size
    }
}

enum DetectionError: Error {
    case failed
    case invalidFrame
    case timeout
} 