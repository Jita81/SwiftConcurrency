// FILE_INFO_START
// PRODUCT: Real-time Object Detection App
// MODULE: Tests
// FILE: ObjectDetectionIntegrationTests.swift
// VERSION: 1.1.0
// LAST_UPDATED: 2024-03-19
// DESCRIPTION: Integration tests for object detection system with UIKit
// FILE_INFO_END

// USER_STORY_START
// AS A developer
// I WANT to verify the entire object detection system works correctly
// SO THAT I can ensure reliable operation in production
// USER_STORY_END

import XCTest
import UIKit
@testable import Concurency

final class ObjectDetectionIntegrationTests: XCTestCase {
    var viewModel: VideoProcessorViewModel!
    var mockService: AdvancedMockDetectionService!
    var mockView: UIView!
    
    override func setUp() {
        super.setUp()
        mockService = AdvancedMockDetectionService()
        viewModel = VideoProcessorViewModel(detectionService: mockService)
        mockView = UIView(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndProcessing() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Process video stream")
        let frameCount = 100
        var processedFrames = 0
        var detectedObjects: [[DetectedObject]] = []
        
        // Create test stream
        let frames = generateTestFrames(count: frameCount)
        let stream = AsyncStream<VideoFrame> { continuation in
            Task {
                for frame in frames {
                    continuation.yield(frame)
                    try? await Task.sleep(nanoseconds: 16_666_667) // 60fps
                }
                continuation.finish()
                expectation.fulfill()
            }
        }
        
        // When
        viewModel.processFrames(stream)
        
        // Observe results
        let cancellable = viewModel.$detectedObjects
            .sink { objects in
                detectedObjects.append(objects)
                processedFrames += 1
            }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        cancellable.cancel()
        
        // Then
        XCTAssertEqual(processedFrames, frameCount, "All frames should be processed")
        XCTAssertTrue(viewModel.statistics.averageProcessingTime < 0.1, "Processing time should be under 100ms")
        XCTAssertTrue(viewModel.statistics.currentFPS >= 30, "Should maintain at least 30 FPS")
    }
    
    func testUIResponsiveness() async throws {
        // Given
        let expectation = XCTestExpectation(description: "UI updates")
        let frameCount = 60
        var uiUpdateTimes: [TimeInterval] = []
        
        // Create test stream
        let frames = generateTestFrames(count: frameCount)
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
        
        // When
        viewModel.processFrames(stream)
        
        // Measure UI update times
        let cancellable = viewModel.$detectedObjects
            .sink { _ in
                let updateTime = CACurrentMediaTime()
                uiUpdateTimes.append(updateTime)
            }
        
        await fulfillment(of: [expectation], timeout: 3.0)
        cancellable.cancel()
        
        // Then
        let updateIntervals = zip(uiUpdateTimes, uiUpdateTimes.dropFirst())
            .map { $1 - $0 }
        
        let maxUpdateInterval = updateIntervals.max() ?? 0
        XCTAssertLessThan(maxUpdateInterval, 0.05, "UI updates should be under 50ms")
    }
    
    func testErrorRecovery() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Error recovery")
        mockService.failureRate = 0.2 // 20% failure rate
        var errorCount = 0
        var recoveryCount = 0
        
        // Create test stream
        let frames = generateTestFrames(count: 50)
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
        
        // When
        viewModel.processFrames(stream)
        
        // Track errors and recoveries
        let errorCancellable = viewModel.$error
            .sink { error in
                if error != nil {
                    errorCount += 1
                }
            }
        
        let objectsCancellable = viewModel.$detectedObjects
            .sink { objects in
                if !objects.isEmpty {
                    recoveryCount += 1
                }
            }
        
        await fulfillment(of: [expectation], timeout: 3.0)
        errorCancellable.cancel()
        objectsCancellable.cancel()
        
        // Then
        XCTAssertGreaterThan(errorCount, 0, "Should encounter some errors")
        XCTAssertGreaterThan(recoveryCount, errorCount, "Should recover from errors")
    }
    
    func testMemoryManagement() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Memory usage")
        let frameCount = 1000
        var memoryMeasurements: [Int64] = []
        
        // Create test stream
        let frames = generateTestFrames(count: frameCount)
        let stream = AsyncStream<VideoFrame> { continuation in
            Task {
                for frame in frames {
                    continuation.yield(frame)
                    memoryMeasurements.append(getMemoryUsage())
                    try? await Task.sleep(nanoseconds: 8_333_333)
                }
                continuation.finish()
                expectation.fulfill()
            }
        }
        
        // When
        viewModel.processFrames(stream)
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Then
        let maxMemory = memoryMeasurements.max() ?? 0
        XCTAssertLessThan(maxMemory, 50_000_000, "Memory usage should stay under 50MB")
        
        // Check for memory leaks
        viewModel.stopProcessing()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        let finalMemory = getMemoryUsage()
        XCTAssertLessThan(finalMemory, maxMemory, "Memory should be released after stopping")
    }
    
    func testConcurrentStreams() async throws {
        // Given
        let streamCount = 4
        var viewModels: [VideoProcessorViewModel] = []
        var expectations: [XCTestExpectation] = []
        
        // Create multiple streams
        for i in 0..<streamCount {
            let expectation = XCTestExpectation(description: "Stream \(i)")
            expectations.append(expectation)
            
            let service = AdvancedMockDetectionService()
            let vm = VideoProcessorViewModel(detectionService: service)
            viewModels.append(vm)
            
            let frames = generateTestFrames(count: 30)
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
        
        await fulfillment(of: expectations, timeout: 5.0)
        
        // Then
        for vm in viewModels {
            XCTAssertFalse(vm.isProcessing)
            XCTAssertNil(vm.error)
            XCTAssertTrue(vm.statistics.currentFPS >= 30)
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateTestFrames(count: Int) -> [VideoFrame] {
        var frames: [VideoFrame] = []
        
        for i in 0..<count {
            let complexity = Double(i % 3 + 1)
            let frameData = generateFrameData(complexity: complexity)
            let frame = VideoFrame(
                data: frameData,
                timestamp: Date().timeIntervalSince1970 + Double(i) / 60.0,
                size: CGSize(width: 1920, height: 1080),
                orientation: .up,
                previewImage: UIImage()
            )
            frames.append(frame)
        }
        
        return frames
    }
    
    private func generateFrameData(complexity: Double) -> Data {
        let baseSize = Int(1920 * 1080 * 3 * complexity)
        var data = Data(count: baseSize)
        for i in 0..<baseSize {
            data[i] = UInt8((sin(Double(i)) + 1) * 127.5)
        }
        return data
    }
    
    private func getMemoryUsage() -> Int64 {
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