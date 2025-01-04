// FILE_INFO_START
// PRODUCT: Real-time Object Detection App
// MODULE: ViewModels
// FILE: VideoProcessorViewModel.swift
// VERSION: 1.1.0
// LAST_UPDATED: 2024-03-19
// DESCRIPTION: Video processing view model with UIKit integration and performance monitoring
// FILE_INFO_END

// USER_STORY_START
// AS A developer
// I WANT to manage video processing and UI updates efficiently
// SO THAT I can display detection results in real-time without blocking the UI
// USER_STORY_END

import SwiftUI
import Combine
import AsyncAlgorithms
import UIKit
import os.log

/// View model for managing video processing and UI updates
@MainActor
public final class VideoProcessorViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Currently detected objects
    @Published public private(set) var detectedObjects: [DetectedObject] = []
    
    /// Processing status
    @Published public private(set) var isProcessing = false
    
    /// Current error state
    @Published public private(set) var error: Error?
    
    /// Current frame being displayed
    @Published public private(set) var currentFrame: VideoFrame?
    
    /// Processing statistics
    @Published public private(set) var statistics = ProcessingStatistics()
    
    // MARK: - Private Properties
    
    private let detectionService: ObjectDetectionService
    private var processingTask: Task<Void, Never>?
    private let frameProcessingQueue: DispatchQueue
    private let logger = Logger(subsystem: "com.app.videoprocessing", category: "ViewModel")
    
    // Performance monitoring
    private var performanceMonitor = PerformanceMonitor()
    private let performanceUpdateInterval: TimeInterval = 1.0
    private var lastPerformanceUpdate = Date()
    
    // Frame management
    private var frameBuffer: CircularBuffer<VideoFrame>
    private let maxBufferSize = 5
    private var lastProcessedFrameIndex = 0
    
    // MARK: - Initialization
    
    public init(detectionService: ObjectDetectionService) {
        self.detectionService = detectionService
        self.frameProcessingQueue = DispatchQueue(
            label: "com.app.frameprocessing",
            qos: .userInteractive,
            attributes: .concurrent
        )
        self.frameBuffer = CircularBuffer(capacity: maxBufferSize)
        
        setupPerformanceMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Process a stream of video frames
    public func processFrames(_ frames: AsyncStream<VideoFrame>) {
        processingTask?.cancel()
        resetState()
        
        processingTask = Task {
            isProcessing = true
            defer { 
                isProcessing = false
                updateStatistics()
            }
            
            do {
                // Process frames with back-pressure handling
                for await frame in frames {
                    guard !Task.isCancelled else { break }
                    
                    // Update frame buffer
                    frameBuffer.append(frame)
                    
                    // Process frame
                    try await processFrame(frame)
                    
                    // Update performance metrics
                    updatePerformanceMetrics()
                }
            } catch {
                await handleError(error)
            }
        }
    }
    
    /// Stop processing frames
    public func stopProcessing() {
        processingTask?.cancel()
        processingTask = nil
        resetState()
    }
    
    /// Update processing configuration
    public func updateConfiguration(_ config: DetectionConfiguration) {
        detectionService.configuration = config
        logger.info("Updated detection configuration: \(config)")
    }
    
    // MARK: - Private Methods
    
    private func processFrame(_ frame: VideoFrame) async throws {
        let startTime = DispatchTime.now()
        
        do {
            // Process frame with timeout protection
            let result = try await withThrowingTaskGroup(of: DetectionResult.self) { group in
                group.addTask {
                    try await self.detectionService.detectObjects(in: frame)
                }
                
                // Add timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms timeout
                    throw DetectionError.timeout
                }
                
                // Return first completed result or throw error
                guard let result = try await group.next() else {
                    throw DetectionError.failed
                }
                
                // Cancel remaining tasks
                group.cancelAll()
                return result
            }
            
            // Update UI state
            await MainActor.run {
                self.detectedObjects = result.objects
                self.currentFrame = frame
                self.error = nil
                self.updateStatistics(with: result)
            }
            
        } catch {
            await handleError(error)
        }
        
        // Update performance metrics
        let endTime = DispatchTime.now()
        let processingTime = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
        performanceMonitor.recordFrameProcessingTime(processingTime)
    }
    
    private func handleError(_ error: Error) async {
        await MainActor.run {
            self.error = error
            logger.error("Detection error: \(error.localizedDescription)")
            statistics.errorCount += 1
        }
    }
    
    private func resetState() {
        detectedObjects = []
        error = nil
        currentFrame = nil
        frameBuffer.removeAll()
        lastProcessedFrameIndex = 0
        statistics = ProcessingStatistics()
        performanceMonitor.reset()
    }
    
    private func setupPerformanceMonitoring() {
        // Start periodic performance updates
        Task {
            while !Task.isCancelled {
                await updatePerformanceMetrics()
                try? await Task.sleep(nanoseconds: UInt64(performanceUpdateInterval * 1_000_000_000))
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        guard Date().timeIntervalSince(lastPerformanceUpdate) >= performanceUpdateInterval else { return }
        
        statistics.averageProcessingTime = performanceMonitor.averageProcessingTime
        statistics.maxProcessingTime = performanceMonitor.maxProcessingTime
        statistics.framesProcessed = performanceMonitor.totalFrames
        statistics.currentFPS = performanceMonitor.currentFPS
        
        lastPerformanceUpdate = Date()
        
        logger.debug("""
            Performance metrics:
            - Average processing time: \(String(format: "%.2f", statistics.averageProcessingTime))ms
            - Max processing time: \(String(format: "%.2f", statistics.maxProcessingTime))ms
            - Frames processed: \(statistics.framesProcessed)
            - Current FPS: \(String(format: "%.1f", statistics.currentFPS))
            """)
    }
    
    private func updateStatistics(with result: DetectionResult) {
        statistics.objectsDetected += result.objects.count
        if result.processingTime > statistics.maxProcessingTime {
            statistics.maxProcessingTime = result.processingTime
        }
    }
}

// MARK: - Supporting Types

/// Statistics for monitoring processing performance
public struct ProcessingStatistics {
    public var framesProcessed: Int = 0
    public var objectsDetected: Int = 0
    public var errorCount: Int = 0
    public var averageProcessingTime: Double = 0
    public var maxProcessingTime: Double = 0
    public var currentFPS: Double = 0
    
    public var description: String {
        """
        Processing Statistics:
        - Frames Processed: \(framesProcessed)
        - Objects Detected: \(objectsDetected)
        - Errors: \(errorCount)
        - Avg Processing Time: \(String(format: "%.2f", averageProcessingTime))ms
        - Max Processing Time: \(String(format: "%.2f", maxProcessingTime))ms
        - Current FPS: \(String(format: "%.1f", currentFPS))
        """
    }
}

/// Circular buffer for managing frame history
private struct CircularBuffer<T> {
    private var buffer: [T]
    private var writeIndex = 0
    private let capacity: Int
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = []
        buffer.reserveCapacity(capacity)
    }
    
    mutating func append(_ element: T) {
        if buffer.count < capacity {
            buffer.append(element)
        } else {
            buffer[writeIndex] = element
        }
        writeIndex = (writeIndex + 1) % capacity
    }
    
    mutating func removeAll() {
        buffer.removeAll(keepingCapacity: true)
        writeIndex = 0
    }
}

/// Performance monitoring helper
private class PerformanceMonitor {
    private var processingTimes: [Double] = []
    private let maxSamples = 100
    private var lastFrameTime = Date()
    
    var totalFrames: Int = 0
    var maxProcessingTime: Double = 0
    
    var averageProcessingTime: Double {
        guard !processingTimes.isEmpty else { return 0 }
        return processingTimes.reduce(0, +) / Double(processingTimes.count)
    }
    
    var currentFPS: Double {
        let interval = Date().timeIntervalSince(lastFrameTime)
        guard interval > 0 else { return 0 }
        return 1.0 / interval
    }
    
    func recordFrameProcessingTime(_ time: Double) {
        processingTimes.append(time)
        if processingTimes.count > maxSamples {
            processingTimes.removeFirst()
        }
        
        maxProcessingTime = max(maxProcessingTime, time)
        totalFrames += 1
        lastFrameTime = Date()
    }
    
    func reset() {
        processingTimes.removeAll()
        totalFrames = 0
        maxProcessingTime = 0
        lastFrameTime = Date()
    }
} 