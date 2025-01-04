"""
#FILE_INFO_START
PRODUCT: Real-time Object Detection App
MODULE: ViewModels
FILE: VideoProcessorViewModel.swift
VERSION: 1.0.0
LAST_UPDATED: 2024-03-19
DESCRIPTION: Manages video processing and UI updates
#FILE_INFO_END
"""

import SwiftUI
import Combine

@MainActor
final class VideoProcessorViewModel: ObservableObject {
    @Published private(set) var detectedObjects: [DetectedObject] = []
    @Published private(set) var isProcessing = false
    @Published private(set) var error: Error?
    
    private let detectionService: ObjectDetectionService
    private var processingTask: Task<Void, Never>?
    
    init(detectionService: ObjectDetectionService) {
        self.detectionService = detectionService
    }
    
    func processFrames(_ frames: AsyncStream<VideoFrame>) {
        processingTask?.cancel()
        
        processingTask = Task {
            isProcessing = true
            defer { isProcessing = false }
            
            for await frame in frames {
                guard !Task.isCancelled else { break }
                
                do {
                    let objects = try await detectionService.detectObjects(in: frame)
                    self.detectedObjects = objects
                    self.error = nil
                } catch {
                    self.error = error
                    print("Detection error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func stopProcessing() {
        processingTask?.cancel()
        processingTask = nil
    }
} 