// FILE_INFO_START
// PRODUCT: Real-time Object Detection App
// MODULE: Tests
// FILE: AdvancedMockDetectionService.swift
// VERSION: 1.1.0
// LAST_UPDATED: 2024-03-19
// DESCRIPTION: Advanced mock service for testing object detection
// FILE_INFO_END

import Foundation
import UIKit
@testable import Concurency

class AdvancedMockDetectionService: ObjectDetectionService {
    var configuration: DetectionConfiguration = .init()
    var failureRate: Double = 0.0
    var processingDelay: TimeInterval = 0.016 // 16ms default
    private var totalOperations: Int = 0
    private var successfulOperations: Int = 0
    private var droppedFrames: Int = 0
    
    func detectObjects(in frame: VideoFrame) async throws -> DetectionResult {
        totalOperations += 1
        
        // Simulate processing delay
        try await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        
        // Simulate random failures
        if Double.random(in: 0...1) < failureRate {
            droppedFrames += 1
            throw DetectionError.failed
        }
        
        // Generate mock objects
        let objectCount = Int.random(in: 1...5)
        var objects: [DetectedObject] = []
        
        for i in 0..<objectCount {
            let confidence = Double.random(in: 0.5...1.0)
            let object = DetectedObject(
                name: "Object\(i)",
                confidence: confidence,
                boundingBox: CGRect(
                    x: Double.random(in: 0...0.8),
                    y: Double.random(in: 0...0.8),
                    width: Double.random(in: 0.1...0.2),
                    height: Double.random(in: 0.1...0.2)
                ),
                displayColor: UIColor(
                    hue: CGFloat(confidence) / 3.0,
                    saturation: 0.8,
                    brightness: 0.8,
                    alpha: 1.0
                ),
                timestamp: frame.timestamp
            )
            objects.append(object)
        }
        
        successfulOperations += 1
        
        return DetectionResult(
            objects: objects,
            processingTime: processingDelay,
            frameInfo: FrameInfo(
                timestamp: frame.timestamp,
                size: frame.size,
                sequenceIndex: totalOperations,
                status: .success
            )
        )
    }
    
    var performanceStats: DetectionPerformanceStats {
        DetectionPerformanceStats(
            averageProcessingTime: processingDelay,
            successRate: totalOperations > 0 ? Double(successfulOperations) / Double(totalOperations) : 0,
            totalProcessedFrames: totalOperations,
            droppedFrames: droppedFrames,
            currentLoad: Double.random(in: 0.3...0.7),
            memoryUsage: Int64(10_000_000)
        )
    }
} 