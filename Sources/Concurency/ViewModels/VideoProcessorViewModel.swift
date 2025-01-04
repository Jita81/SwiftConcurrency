import SwiftUI
import Combine
import AsyncAlgorithms

@MainActor
public final class VideoProcessorViewModel: ObservableObject {
    @Published public private(set) var detectedObjects: [DetectedObject] = []
    @Published public private(set) var isProcessing = false
    @Published public private(set) var error: Error?
    
    // Performance metrics
    private(set) var averageProcessingTime: Double = 0
    private(set) var maxProcessingTime: Double = 0
    private var processingTimeSum: Double = 0
    private var processedFrameCount: Int = 0
    
    private let detectionService: ObjectDetectionService
    private var processingTask: Task<Void, Never>?
    private let frameProcessingQueue: DispatchQueue
    private let maxConcurrentFrames = 4
    private let processingTimeWindow = 100 // Keep track of last 100 frames for average
    private var processingTimes: [Double] = []
    
    public init(detectionService: ObjectDetectionService) {
        self.detectionService = detectionService
        self.frameProcessingQueue = DispatchQueue(
            label: "com.app.frameprocessing",
            qos: .userInteractive,
            attributes: .concurrent
        )
    }
    
    public func processFrames(_ frames: AsyncStream<VideoFrame>) {
        processingTask?.cancel()
        resetMetrics()
        
        processingTask = Task {
            isProcessing = true
            defer { 
                isProcessing = false
                updateMetrics()
            }
            
            // Use AsyncStream's buffering to handle back-pressure
            for await frame in frames {
                guard !Task.isCancelled else { break }
                
                let startTime = DispatchTime.now()
                
                do {
                    // Process frame with timeout protection
                    let objects = try await withThrowingTaskGroup(of: [DetectedObject].self) { group in
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
                    
                    // Update UI on main actor
                    await MainActor.run {
                        self.detectedObjects = objects
                        self.error = nil
                    }
                    
                } catch {
                    await MainActor.run {
                        self.error = error
                        print("Detection error: \(error.localizedDescription)")
                    }
                }
                
                // Update performance metrics
                let endTime = DispatchTime.now()
                let processingTime = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
                updateProcessingMetrics(processingTime)
            }
        }
    }
    
    public func stopProcessing() {
        processingTask?.cancel()
        processingTask = nil
        resetMetrics()
    }
    
    // MARK: - Performance Monitoring
    
    private func updateProcessingMetrics(_ processingTime: Double) {
        processingTimeSum += processingTime
        processedFrameCount += 1
        maxProcessingTime = max(maxProcessingTime, processingTime)
        
        // Keep a rolling window of processing times
        processingTimes.append(processingTime)
        if processingTimes.count > processingTimeWindow {
            if let firstTime = processingTimes.first {
                processingTimeSum -= firstTime
                processingTimes.removeFirst()
            }
        }
        
        // Update rolling average
        averageProcessingTime = processingTimeSum / Double(processingTimes.count)
    }
    
    private func resetMetrics() {
        processingTimeSum = 0
        processedFrameCount = 0
        maxProcessingTime = 0
        averageProcessingTime = 0
        processingTimes.removeAll()
    }
    
    // MARK: - Public Metrics Access
    
    public var currentPerformanceMetrics: PerformanceMetrics {
        PerformanceMetrics(
            averageProcessingTime: averageProcessingTime,
            maxProcessingTime: maxProcessingTime,
            processedFrameCount: processedFrameCount,
            errorCount: error != nil ? 1 : 0
        )
    }
}

public struct PerformanceMetrics {
    public let averageProcessingTime: Double
    public let maxProcessingTime: Double
    public let processedFrameCount: Int
    public let errorCount: Int
} 