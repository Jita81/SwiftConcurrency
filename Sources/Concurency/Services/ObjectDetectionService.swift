// FILE_INFO_START
// PRODUCT: Real-time Object Detection App
// MODULE: Services
// FILE: ObjectDetectionService.swift
// VERSION: 1.1.0
// LAST_UPDATED: 2024-03-19
// DESCRIPTION: Object detection service with UIKit integration and performance optimizations
// FILE_INFO_END

// USER_STORY_START
// AS A developer
// I WANT to process video frames efficiently with UIKit integration
// SO THAT I can detect objects in real-time without blocking the UI
// USER_STORY_END

import Foundation
import CoreImage
import Vision
import UIKit
import os.log

/// Protocol defining the object detection service interface
public protocol ObjectDetectionService: AnyObject {
    /// Process a video frame and return detected objects
    func detectObjects(in frame: VideoFrame) async throws -> DetectionResult
    
    /// Current performance statistics
    var performanceStats: DetectionPerformanceStats { get }
    
    /// Service configuration
    var configuration: DetectionConfiguration { get set }
}

/// Performance statistics for monitoring
public struct DetectionPerformanceStats {
    public let averageProcessingTime: Double
    public let successRate: Double
    public let totalProcessedFrames: Int
    public let droppedFrames: Int
    public let currentLoad: Double
    public let memoryUsage: Int64
    
    public var description: String {
        """
        Performance Stats:
        - Avg Processing Time: \(String(format: "%.2f", averageProcessingTime))ms
        - Success Rate: \(String(format: "%.1f", successRate * 100))%
        - Processed Frames: \(totalProcessedFrames)
        - Dropped Frames: \(droppedFrames)
        - Current Load: \(String(format: "%.1f", currentLoad * 100))%
        - Memory Usage: \(memoryUsage / 1_000_000)MB
        """
    }
}

/// Service configuration options
public struct DetectionConfiguration {
    /// Minimum confidence threshold for detections
    public var confidenceThreshold: Float
    
    /// Maximum concurrent operations
    public var maxConcurrentOperations: Int
    
    /// Operation timeout in seconds
    public var operationTimeout: TimeInterval
    
    /// Whether to generate preview images
    public var generatePreviews: Bool
    
    /// Maximum frame rate
    public var maxFrameRate: Int
    
    public init(
        confidenceThreshold: Float = 0.5,
        maxConcurrentOperations: Int = 4,
        operationTimeout: TimeInterval = 0.1,
        generatePreviews: Bool = true,
        maxFrameRate: Int = 120
    ) {
        self.confidenceThreshold = confidenceThreshold
        self.maxConcurrentOperations = maxConcurrentOperations
        self.operationTimeout = operationTimeout
        self.generatePreviews = generatePreviews
        self.maxFrameRate = maxFrameRate
    }
}

/// Default implementation of the object detection service
public final class DefaultObjectDetectionService: ObjectDetectionService {
    private let queue: DispatchQueue
    private let model: VNCoreMLModel
    private let operationSemaphore: DispatchSemaphore
    private let logger = Logger(subsystem: "com.app.objectdetection", category: "ObjectDetection")
    
    // Performance tracking
    private var totalProcessingTime: Double = 0
    private var successfulOperations: Int = 0
    private var totalOperations: Int = 0
    private var droppedFrameCount: Int = 0
    private let statsLock = NSLock()
    
    // Configuration
    public var configuration: DetectionConfiguration {
        didSet {
            updateConfiguration()
        }
    }
    
    public init(modelURL: URL, configuration: DetectionConfiguration = .init()) throws {
        self.model = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
        self.configuration = configuration
        self.operationSemaphore = DispatchSemaphore(value: configuration.maxConcurrentOperations)
        self.queue = DispatchQueue(
            label: "com.app.objectdetection",
            qos: .userInteractive,
            attributes: .concurrent
        )
        
        setupModel()
    }
    
    public func detectObjects(in frame: VideoFrame) async throws -> DetectionResult {
        let startTime = DispatchTime.now()
        var frameInfo = FrameInfo(
            timestamp: frame.timestamp,
            size: frame.size,
            sequenceIndex: totalOperations,
            status: .success
        )
        
        defer {
            let endTime = DispatchTime.now()
            updatePerformanceStats(
                processingTime: Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000,
                success: frameInfo.status.isSuccess
            )
        }
        
        // Implement back-pressure using semaphore
        guard operationSemaphore.wait(timeout: .now() + configuration.operationTimeout) == .success else {
            frameInfo.status = .dropped
            droppedFrameCount += 1
            throw DetectionError.timeout
        }
        
        defer { operationSemaphore.signal() }
        
        return try await withThrowingTaskGroup(of: DetectionResult.self) { group in
            group.addTask {
                try await self.processFrame(frame, frameInfo: frameInfo)
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(configuration.operationTimeout * 1_000_000_000))
                throw DetectionError.timeout
            }
            
            // Return first completed result
            guard let result = try await group.next() else {
                throw DetectionError.failed
            }
            
            // Cancel remaining tasks
            group.cancelAll()
            return result
        }
    }
    
    public var performanceStats: DetectionPerformanceStats {
        statsLock.lock()
        defer { statsLock.unlock() }
        
        return DetectionPerformanceStats(
            averageProcessingTime: totalOperations > 0 ? totalProcessingTime / Double(totalOperations) : 0,
            successRate: totalOperations > 0 ? Double(successfulOperations) / Double(totalOperations) : 0,
            totalProcessedFrames: totalOperations,
            droppedFrames: droppedFrameCount,
            currentLoad: Double(configuration.maxConcurrentOperations - operationSemaphore.value) / Double(configuration.maxConcurrentOperations),
            memoryUsage: reportMemoryUsage()
        )
    }
    
    // MARK: - Private Methods
    
    private func processFrame(_ frame: VideoFrame, frameInfo: FrameInfo) async throws -> DetectionResult {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    // Convert frame data to CIImage
                    guard let ciImage = CIImage(data: frame.data) else {
                        continuation.resume(throwing: DetectionError.invalidFrame)
                        return
                    }
                    
                    // Create and configure request
                    let request = VNCoreMLRequest(model: self.model) { request, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }
                        
                        guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                            continuation.resume(throwing: DetectionError.failed)
                            return
                        }
                        
                        // Process observations
                        let objects = observations
                            .filter { $0.confidence >= self.configuration.confidenceThreshold }
                            .map { observation -> DetectedObject in
                                let confidence = Double(observation.confidence)
                                let label = observation.labels.first?.identifier ?? "Unknown"
                                return DetectedObject(
                                    name: label,
                                    confidence: confidence,
                                    boundingBox: observation.boundingBox,
                                    displayColor: self.colorForConfidence(confidence),
                                    timestamp: frame.timestamp
                                )
                            }
                        
                        // Create result
                        let result = DetectionResult(
                            objects: objects,
                            processingTime: frame.timestamp - Date().timeIntervalSince1970,
                            frameInfo: frameInfo
                        )
                        
                        continuation.resume(returning: result)
                    }
                    
                    // Configure request
                    request.imageCropAndScaleOption = .scaleFit
                    
                    // Create handler and perform request
                    let handler = VNImageRequestHandler(
                        ciImage: ciImage,
                        orientation: frame.orientation.toCGImagePropertyOrientation(),
                        options: [.preferBackgroundProcessing: true]
                    )
                    
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func setupModel() {
        // Model-specific setup and optimization
        model.featureProvider = try? MLDictionaryFeatureProvider(dictionary: [:])
        model.modelDescription.metadata[MLModelDescriptionKey.computeUnits] = MLComputeUnits.all.rawValue
    }
    
    private func updateConfiguration() {
        // Update internal configuration
        operationSemaphore.signal()
        for _ in 0..<configuration.maxConcurrentOperations {
            operationSemaphore.wait()
        }
    }
    
    private func updatePerformanceStats(processingTime: Double, success: Bool) {
        statsLock.lock()
        defer { statsLock.unlock() }
        
        totalProcessingTime += processingTime
        totalOperations += 1
        if success {
            successfulOperations += 1
        }
        
        // Log performance metrics
        logger.debug("""
            Frame processed:
            - Processing time: \(String(format: "%.2f", processingTime))ms
            - Success: \(success)
            - Total frames: \(totalOperations)
            """)
    }
    
    private func colorForConfidence(_ confidence: Double) -> UIColor {
        let hue = CGFloat(confidence) / 3.0 // Use first third of hue spectrum
        return UIColor(hue: hue, saturation: 0.8, brightness: 0.8, alpha: 1.0)
    }
    
    private func reportMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Extensions

extension UIImage.Orientation {
    func toCGImagePropertyOrientation() -> CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
} 