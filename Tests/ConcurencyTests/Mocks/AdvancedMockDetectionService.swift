import Foundation
import CoreGraphics
@testable import Concurency

class AdvancedMockDetectionService: ObjectDetectionService {
    // Configuration
    var failureRate: Double = 0
    var processingTimeVariability: Double = 0.2 // 20% variation in processing time
    var baseProcessingTime: UInt64 = 50_000_000 // 50ms base
    var simulateNetworkLatency: Bool = false
    var simulateThermalThrottling: Bool = false
    
    // State tracking
    private(set) var lastOperationSucceeded = true
    private(set) var processedFrames = 0
    private var currentLoad: Double = 0
    private let loadLock = NSLock()
    private var thermalState: ProcessingThermalState = .normal
    
    // Performance tracking
    private var totalProcessingTime: Double = 0
    private var successfulOperations: Int = 0
    private var totalOperations: Int = 0
    private let statsLock = NSLock()
    
    enum ProcessingThermalState {
        case normal
        case elevated
        case critical
        
        var processingMultiplier: Double {
            switch self {
            case .normal: return 1.0
            case .elevated: return 1.5
            case .critical: return 2.0
            }
        }
    }
    
    func detectObjects(in frame: VideoFrame) async throws -> [DetectedObject] {
        processedFrames += 1
        
        // Update system load
        updateSystemLoad()
        
        // Calculate processing time based on various factors
        let processingTime = calculateProcessingTime(for: frame)
        
        if simulateNetworkLatency {
            try await simulateNetworkDelay()
        }
        
        // Simulate processing
        try await Task.sleep(nanoseconds: processingTime)
        
        // Simulate random failures
        if shouldSimulateFailure() {
            lastOperationSucceeded = false
            throw DetectionError.failed
        }
        
        lastOperationSucceeded = true
        
        // Generate detection results
        let results = generateDetectionResults(for: frame)
        
        // Update performance stats
        updatePerformanceStats(
            processingTime: Double(processingTime) / 1_000_000_000,
            success: true
        )
        
        return results
    }
    
    // MARK: - Performance Stats
    
    public var performanceStats: DetectionPerformanceStats {
        statsLock.lock()
        defer { statsLock.unlock() }
        
        return DetectionPerformanceStats(
            averageProcessingTime: totalOperations > 0 ? totalProcessingTime / Double(totalOperations) : 0,
            successRate: totalOperations > 0 ? Double(successfulOperations) / Double(totalOperations) : 0,
            totalProcessedFrames: totalOperations
        )
    }
    
    // MARK: - Private Helpers
    
    private func updateSystemLoad() {
        loadLock.lock()
        defer { loadLock.unlock() }
        
        // Simulate gradual load increase
        currentLoad = min(1.0, currentLoad + 0.01)
        
        // Update thermal state based on load
        if currentLoad > 0.8 {
            thermalState = .critical
        } else if currentLoad > 0.6 {
            thermalState = .elevated
        } else {
            thermalState = .normal
        }
    }
    
    private func calculateProcessingTime(for frame: VideoFrame) -> UInt64 {
        let complexity = Double(frame.data.count) / Double(1920 * 1080 * 3)
        let variability = Double.random(in: 1.0 - processingTimeVariability...1.0 + processingTimeVariability)
        let thermalMultiplier = simulateThermalThrottling ? thermalState.processingMultiplier : 1.0
        let loadFactor = 1.0 + (currentLoad * 0.5) // Up to 50% slower under load
        
        let adjustedTime = Double(baseProcessingTime) * 
            complexity * 
            variability * 
            thermalMultiplier * 
            loadFactor
        
        return min(UInt64(adjustedTime), 100_000_000) // Cap at 100ms
    }
    
    private func simulateNetworkDelay() async throws {
        let delay = UInt64(Double.random(in: 10_000_000...30_000_000)) // 10-30ms
        try await Task.sleep(nanoseconds: delay)
    }
    
    private func shouldSimulateFailure() -> Bool {
        // Increase failure rate under high load
        let adjustedFailureRate = failureRate * (1 + currentLoad)
        return Double.random(in: 0...1) < adjustedFailureRate
    }
    
    private func generateDetectionResults(for frame: VideoFrame) -> [DetectedObject] {
        let complexity = Double(frame.data.count) / Double(1920 * 1080 * 3)
        let objectCount = Int(complexity * 5)
        
        return (0..<objectCount).map { i in
            let confidence = Double.random(in: 0.75...0.99)
            let name = ["Car", "Person", "Bicycle", "Dog", "Cat"][i % 5]
            
            // Generate more realistic bounding boxes
            let x = Double.random(in: 0...0.8) // Leave room for object width
            let y = Double.random(in: 0...0.8) // Leave room for object height
            let width = Double.random(in: 0.1...0.3)
            let height = Double.random(in: 0.1...0.3)
            let boundingBox = CGRect(x: x, y: y, width: width, height: height)
            
            return DetectedObject(name: name, confidence: confidence, boundingBox: boundingBox)
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
    }
} 