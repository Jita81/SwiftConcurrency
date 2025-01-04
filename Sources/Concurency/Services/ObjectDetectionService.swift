import Foundation
import CoreImage
import Vision

public protocol ObjectDetectionService {
    func detectObjects(in frame: VideoFrame) async throws -> [DetectedObject]
    var performanceStats: DetectionPerformanceStats { get }
}

public struct DetectionPerformanceStats {
    public let averageProcessingTime: Double
    public let successRate: Double
    public let totalProcessedFrames: Int
}

public final class DefaultObjectDetectionService: ObjectDetectionService {
    private let queue: DispatchQueue
    private let model: VNCoreMLModel
    private let maxConcurrentOperations: Int
    private let operationSemaphore: DispatchSemaphore
    
    // Performance tracking
    private var totalProcessingTime: Double = 0
    private var successfulOperations: Int = 0
    private var totalOperations: Int = 0
    private let statsLock = NSLock()
    
    public init(modelURL: URL, maxConcurrentOperations: Int = 4) throws {
        self.model = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
        self.maxConcurrentOperations = maxConcurrentOperations
        self.operationSemaphore = DispatchSemaphore(value: maxConcurrentOperations)
        self.queue = DispatchQueue(
            label: "com.app.objectdetection",
            qos: .userInteractive,
            attributes: .concurrent
        )
    }
    
    public func detectObjects(in frame: VideoFrame) async throws -> [DetectedObject] {
        let startTime = DispatchTime.now()
        defer {
            let endTime = DispatchTime.now()
            updatePerformanceStats(
                processingTime: Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000,
                success: true
            )
        }
        
        // Implement back-pressure using semaphore
        return try await withCheckedThrowingContinuation { continuation in
            // Ensure we don't exceed maximum concurrent operations
            guard operationSemaphore.wait(timeout: .now() + .seconds(1)) == .success else {
                continuation.resume(throwing: DetectionError.timeout)
                return
            }
            
            defer { operationSemaphore.signal() }
            
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
                        
                        guard let observations = request.results as? [VNClassificationObservation] else {
                            continuation.resume(throwing: DetectionError.failed)
                            return
                        }
                        
                        // Filter and map observations
                        let results = observations
                            .filter { $0.confidence > 0.5 } // Only include confident detections
                            .map { observation -> DetectedObject in
                                let boundingBox = observation.boundingBox ?? .zero
                                return DetectedObject(
                                    name: observation.identifier,
                                    confidence: Double(observation.confidence),
                                    boundingBox: boundingBox
                                )
                            }
                        
                        continuation.resume(returning: results)
                    }
                    
                    // Configure request for optimal performance
                    request.imageCropAndScaleOption = .scaleFit
                    
                    // Create handler and perform request
                    let handler = VNImageRequestHandler(
                        ciImage: ciImage,
                        orientation: .up,
                        options: [.preferBackgroundProcessing: true]
                    )
                    
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Performance Tracking
    
    private func updatePerformanceStats(processingTime: Double, success: Bool) {
        statsLock.lock()
        defer { statsLock.unlock() }
        
        totalProcessingTime += processingTime
        totalOperations += 1
        if success {
            successfulOperations += 1
        }
    }
    
    public var performanceStats: DetectionPerformanceStats {
        statsLock.lock()
        defer { statsLock.unlock() }
        
        return DetectionPerformanceStats(
            averageProcessingTime: totalOperations > 0 ? totalProcessingTime / Double(totalOperations) : 0,
            successRate: totalOperations > 0 ? Double(successfulOperations) / Double(totalOperations) : 0,
            totalProcessedFrames: totalOperations
        )
    }
} 