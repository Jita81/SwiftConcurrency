"""
#FILE_INFO_START
PRODUCT: Real-time Object Detection App
MODULE: Tests
FILE: ObjectDetectionTests.swift
VERSION: 1.0.0
LAST_UPDATED: 2024-03-19
DESCRIPTION: Unit tests for object detection functionality
#FILE_INFO_END
"""

import XCTest
@testable import YourAppModule

final class ObjectDetectionTests: XCTestCase {
    var viewModel: VideoProcessorViewModel!
    var mockDetectionService: MockObjectDetectionService!
    
    override func setUp() {
        super.setUp()
        mockDetectionService = MockObjectDetectionService()
        viewModel = VideoProcessorViewModel(detectionService: mockDetectionService)
    }
    
    func testSuccessfulDetection() async throws {
        // Given
        let expectedObject = DetectedObject(name: "Car", confidence: 0.95)
        mockDetectionService.mockResult = [expectedObject]
        
        let frame = VideoFrame(data: Data())
        
        // When
        let objects = try await mockDetectionService.detectObjects(in: frame)
        
        // Then
        XCTAssertEqual(objects.count, 1)
        XCTAssertEqual(objects.first?.name, expectedObject.name)
        XCTAssertEqual(objects.first?.confidence, expectedObject.confidence)
    }
    
    func testDetectionError() async {
        // Given
        mockDetectionService.shouldFail = true
        let frame = VideoFrame(data: Data())
        
        // When/Then
        do {
            _ = try await mockDetectionService.detectObjects(in: frame)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? DetectionError, .failed)
        }
    }
    
    func testProcessingCancellation() async {
        // Given
        let frames = AsyncStream { continuation in
            continuation.yield(VideoFrame(data: Data()))
            continuation.finish()
        }
        
        // When
        viewModel.processFrames(frames)
        viewModel.stopProcessing()
        
        // Then
        XCTAssertFalse(viewModel.isProcessing)
    }
}

// Mock service for testing
class MockObjectDetectionService: ObjectDetectionService {
    var mockResult: [DetectedObject] = []
    var shouldFail = false
    
    func detectObjects(in frame: VideoFrame) async throws -> [DetectedObject] {
        if shouldFail {
            throw DetectionError.failed
        }
        return mockResult
    }
} 