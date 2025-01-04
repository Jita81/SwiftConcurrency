import XCTest
@testable import Concurency

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
        let frames = AsyncStream<VideoFrame> { continuation in
            continuation.yield(VideoFrame(data: Data()))
            continuation.finish()
        }
        
        // When
        viewModel.processFrames(frames)
        viewModel.stopProcessing()
        
        // Then
        XCTAssertFalse(viewModel.isProcessing)
    }
    
    func testFrameProcessingPerformance() async throws {
        // Given
        let frame = VideoFrame(data: Data())
        mockDetectionService.mockResult = [DetectedObject(name: "Car", confidence: 0.95)]
        
        // When
        measure {
            Task {
                _ = try? await mockDetectionService.detectObjects(in: frame)
            }
        }
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
        // Simulate processing time
        try? await Task.sleep(nanoseconds: 50_000_000)
        return mockResult
    }
} 