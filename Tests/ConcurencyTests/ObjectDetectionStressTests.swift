import XCTest
import CoreImage
@testable import Concurency

final class ObjectDetectionStressTests: XCTestCase {
    var viewModel: VideoProcessorViewModel!
    var mockDetectionService: AdvancedMockDetectionService!
    var performanceMetrics: PerformanceMetrics!
    
    override func setUp() {
        super.setUp()
        mockDetectionService = AdvancedMockDetectionService()
        viewModel = VideoProcessorViewModel(detectionService: mockDetectionService)
        performanceMetrics = PerformanceMetrics()
    }
    
    // MARK: - High Load Tests
    
    func testHighFrequencyFrameProcessing() async throws {
        // Test processing frames at 120fps
        let expectation = XCTestExpectation(description: "Process 120 frames")
        let frameCount = 120
        var processedFrames = 0
        var maxProcessingTime: Double = 0
        var totalProcessingTime: Double = 0
        
        // Generate test frames with varying complexity
        let frames = generateComplexFrames(count: frameCount)
        
        // Create high-frequency frame stream
        let stream = AsyncStream<VideoFrame> { continuation in
            Task {
                for frame in frames {
                    let startTime = DispatchTime.now()
                    continuation.yield(frame)
                    
                    // Measure processing time
                    let endTime = DispatchTime.now()
                    let processingTime = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
                    maxProcessingTime = max(maxProcessingTime, processingTime)
                    totalProcessingTime += processingTime
                    
                    processedFrames += 1
                    try? await Task.sleep(nanoseconds: 8_333_333) // ~120fps
                }
                continuation.finish()
                expectation.fulfill()
            }
        }
        
        // Process frames and measure performance
        viewModel.processFrames(stream)
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Verify performance metrics
        let averageProcessingTime = totalProcessingTime / Double(frameCount)
        XCTAssertLessThan(maxProcessingTime, 0.1, "Max processing time exceeded 100ms")
        XCTAssertLessThan(averageProcessingTime, 0.05, "Average processing time exceeded 50ms")
        XCTAssertEqual(processedFrames, frameCount, "Not all frames were processed")
    }
    
    // MARK: - Concurrent Processing Tests
    
    func testParallelFrameProcessing() async throws {
        let concurrentStreams = 4
        var expectations: [XCTestExpectation] = []
        var viewModels: [VideoProcessorViewModel] = []
        
        // Create multiple streams processing frames simultaneously
        for i in 0..<concurrentStreams {
            let expectation = XCTestExpectation(description: "Stream \(i) completed")
            expectations.append(expectation)
            
            let service = AdvancedMockDetectionService()
            let vm = VideoProcessorViewModel(detectionService: service)
            viewModels.append(vm)
            
            let frames = generateComplexFrames(count: 30)
            let stream = AsyncStream<VideoFrame> { continuation in
                Task {
                    for frame in frames {
                        continuation.yield(frame)
                        try? await Task.sleep(nanoseconds: 16_666_667)
                    }
                    continuation.finish()
                    expectation.fulfill()
                }
            }
            
            vm.processFrames(stream)
        }
        
        await fulfillment(of: expectations, timeout: 10.0)
        
        // Verify all streams completed successfully
        for vm in viewModels {
            XCTAssertFalse(vm.isProcessing)
            XCTAssertNil(vm.error)
        }
    }
    
    // MARK: - Error Recovery and Resilience Tests
    
    func testErrorRecoveryUnderLoad() async throws {
        let expectation = XCTestExpectation(description: "Process frames with errors")
        var successfulFrames = 0
        var failedFrames = 0
        let totalFrames = 100
        
        // Configure service to fail intermittently
        mockDetectionService.failureRate = 0.2 // 20% failure rate
        
        let frames = generateComplexFrames(count: totalFrames)
        let stream = AsyncStream<VideoFrame> { continuation in
            Task {
                for frame in frames {
                    continuation.yield(frame)
                    if mockDetectionService.lastOperationSucceeded {
                        successfulFrames += 1
                    } else {
                        failedFrames += 1
                    }
                    try? await Task.sleep(nanoseconds: 16_666_667)
                }
                continuation.finish()
                expectation.fulfill()
            }
        }
        
        viewModel.processFrames(stream)
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Verify error handling
        XCTAssertGreaterThan(successfulFrames, 0, "No frames processed successfully")
        XCTAssertGreaterThan(failedFrames, 0, "No error cases tested")
        XCTAssertEqual(successfulFrames + failedFrames, totalFrames, "Not all frames were processed")
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagementUnderLoad() async throws {
        let frameCount = 1000 // Large number of frames
        let expectation = XCTestExpectation(description: "Process large number of frames")
        
        let frames = generateComplexFrames(count: frameCount)
        var memoryMeasurements: [Int] = []
        
        let stream = AsyncStream<VideoFrame> { continuation in
            Task {
                for frame in frames {
                    continuation.yield(frame)
                    memoryMeasurements.append(performanceMetrics.currentMemoryUsage())
                    try? await Task.sleep(nanoseconds: 8_333_333)
                }
                continuation.finish()
                expectation.fulfill()
            }
        }
        
        viewModel.processFrames(stream)
        
        await fulfillment(of: [expectation], timeout: 30.0)
        
        // Analyze memory usage pattern
        let maxMemory = memoryMeasurements.max() ?? 0
        let averageMemory = Double(memoryMeasurements.reduce(0, +)) / Double(memoryMeasurements.count)
        
        XCTAssertLessThan(maxMemory, 50_000_000, "Memory usage exceeded 50MB")
        XCTAssertLessThan(averageMemory, 10_000_000, "Average memory usage exceeded 10MB")
    }
    
    // MARK: - Helper Methods
    
    private func generateComplexFrames(count: Int) -> [VideoFrame] {
        var frames: [VideoFrame] = []
        
        for i in 0..<count {
            // Generate frames with varying complexity
            let complexity = Double(i % 3) + 1 // 1, 2, or 3 times base complexity
            let frameData = generateComplexFrameData(complexity: complexity)
            let size = CGSize(width: 1920, height: 1080) // Full HD frames
            frames.append(VideoFrame(data: frameData, size: size))
        }
        
        return frames
    }
    
    private func generateComplexFrameData(complexity: Double) -> Data {
        // Simulate different frame complexities
        let baseSize = Int(1920 * 1080 * 3 * complexity) // RGB data
        var data = Data(count: baseSize)
        
        // Fill with pseudo-random data
        for i in 0..<baseSize {
            data[i] = UInt8((sin(Double(i)) + 1) * 127.5)
        }
        
        return data
    }
}

// MARK: - Advanced Mock Service

class AdvancedMockDetectionService: ObjectDetectionService {
    var failureRate: Double = 0
    var lastOperationSucceeded = true
    private var processedFrames = 0
    
    func detectObjects(in frame: VideoFrame) async throws -> [DetectedObject] {
        processedFrames += 1
        
        // Simulate varying processing times based on frame size and complexity
        let baseProcessingTime = UInt64(50_000_000) // 50ms base
        let complexityFactor = Double(frame.data.count) / Double(1920 * 1080 * 3)
        let processingTime = UInt64(Double(baseProcessingTime) * complexityFactor)
        
        try await Task.sleep(nanoseconds: min(processingTime, 100_000_000))
        
        // Simulate random failures
        if Double.random(in: 0...1) < failureRate {
            lastOperationSucceeded = false
            throw DetectionError.failed
        }
        
        lastOperationSucceeded = true
        
        // Generate varying numbers of detected objects based on frame complexity
        let objectCount = Int(complexityFactor * 5)
        return (0..<objectCount).map { i in
            let confidence = Double.random(in: 0.75...0.99)
            let name = ["Car", "Person", "Bicycle", "Dog", "Cat"][i % 5]
            let x = Double.random(in: 0...1)
            let y = Double.random(in: 0...1)
            let width = Double.random(in: 0.1...0.3)
            let height = Double.random(in: 0.1...0.3)
            let boundingBox = CGRect(x: x, y: y, width: width, height: height)
            
            return DetectedObject(name: name, confidence: confidence, boundingBox: boundingBox)
        }
    }
}

// MARK: - Performance Metrics Helper

class PerformanceMetrics {
    func currentMemoryUsage() -> Int {
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
        
        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
} 