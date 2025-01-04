// FILE_INFO_START
// PRODUCT: Real-time Object Detection App
// MODULE: ViewModels
// FILE: VideoProcessorViewModel.swift
// VERSION: 1.1.0
// LAST_UPDATED: 2024-03-19
// DESCRIPTION: Video processing view model with platform-agnostic design
// FILE_INFO_END

// USER_STORY_START
// AS A developer
// I WANT to manage video processing and UI updates efficiently
// SO THAT I can display detection results in real-time without blocking the UI
// USER_STORY_END

import Foundation
import Combine
import AsyncAlgorithms
import os.log
import Platform

/// View model for managing video processing and UI updates
@MainActor
public final class VideoProcessorViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Current detection results
    @Published public private(set) var detectionResults: [DetectedObject] = []
    
    /// Processing statistics
    @Published public private(set) var statistics = ProcessingStatistics()
    
    /// Whether frame processing is active
    @Published public private(set) var isProcessing = false
    
    /// Current error state
    @Published public private(set) var error: DetectionError?
    
    // MARK: - Private Properties
    
    private let detectionService: ObjectDetectionService
    private let frameChannel: AsyncChannel<VideoFrame>
    private let performanceUpdateInterval: TimeInterval
    private let logger = Logger(subsystem: "com.app.objectdetection", category: "VideoProcessing")
    private var processingTask: Task<Void, Never>?
    private var performanceMonitoringTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    public init(
        detectionService: ObjectDetectionService,
        performanceUpdateInterval: TimeInterval = 1.0
    ) {
        self.detectionService = detectionService
        self.frameChannel = AsyncChannel()
        self.performanceUpdateInterval = performanceUpdateInterval
        setupProcessing()
    }
    
    // MARK: - Public Methods
    
    public func processFrame(_ frame: VideoFrame) {
        Task {
            await frameChannel.send(frame)
        }
    }
    
    public func startProcessing() {
        guard processingTask == nil else { return }
        setupProcessing()
    }
    
    public func stopProcessing() {
        processingTask?.cancel()
        processingTask = nil
        performanceMonitoringTask?.cancel()
        performanceMonitoringTask = nil
        isProcessing = false
    }
    
    public func updateConfiguration(_ config: DetectionConfiguration) {
        detectionService.configuration = config
        logger.info("Updated detection configuration: \(String(describing: config))")
    }
    
    // MARK: - Private Methods
    
    private func setupProcessing() {
        processingTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await frame in self.frameChannel {
                guard !Task.isCancelled else { break }
                
                do {
                    isProcessing = true
                    let result = try await detectionService.detectObjects(in: frame)
                    self.updateStatistics(with: result)
                    detectionResults = result.objects
                    error = nil
                } catch let detectionError as DetectionError {
                    error = detectionError
                    logger.error("Detection error: \(detectionError.localizedDescription)")
                } catch {
                    self.error = .failed
                    logger.error("Unexpected error: \(error.localizedDescription)")
                }
                
                isProcessing = false
            }
        }
        
        setupPerformanceMonitoring()
    }
    
    private func setupPerformanceMonitoring() {
        performanceMonitoringTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                self.updatePerformanceMetrics()
                try? await Task.sleep(nanoseconds: UInt64(performanceUpdateInterval * 1_000_000_000))
            }
        }
    }
    
    private func updateStatistics(with result: DetectionResult) {
        statistics.objectsDetected += result.objects.count
        if result.processingTime > statistics.maxProcessingTime {
            statistics.maxProcessingTime = result.processingTime
        }
        statistics.totalProcessingTime += result.processingTime
        statistics.framesProcessed += 1
        statistics.averageProcessingTime = statistics.totalProcessingTime / Double(statistics.framesProcessed)
        statistics.currentFPS = 1.0 / result.processingTime
    }
    
    private func updatePerformanceMetrics() {
        _ = detectionService.performanceStats
        
        logger.debug("""
            Performance metrics:
            - Average processing time: \(String(format: "%.2f", self.statistics.averageProcessingTime))ms
            - Max processing time: \(String(format: "%.2f", self.statistics.maxProcessingTime))ms
            - Frames processed: \(self.statistics.framesProcessed)
            - Current FPS: \(String(format: "%.1f", self.statistics.currentFPS))
            """)
    }
}

/// Statistics for frame processing
public struct ProcessingStatistics {
    public var objectsDetected: Int = 0
    public var framesProcessed: Int = 0
    public var totalProcessingTime: Double = 0
    public var averageProcessingTime: Double = 0
    public var maxProcessingTime: Double = 0
    public var currentFPS: Double = 0
    
    public init() {}
} 