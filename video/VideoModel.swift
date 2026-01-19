import Foundation
import SwiftUI

// MARK: - Data Model
struct VideoStep: Codable, Identifiable, Equatable {
    var id: String
    var stepNumber: Int
    var relativePath: String // We store relative path to keep it valid between app launches
    var originalName: String
    
    // Computed property to get the full URL dynamically
    var fullURL: URL? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documents?.appendingPathComponent(relativePath)
    }
}

// MARK: - Video Manager (The Store)
@MainActor
class VideoManager: ObservableObject {
    @Published var videos: [VideoStep] = []
    @Published var isLoading: Bool = false
    @Published var totalSteps: Int = 3
    
    private let metaFileName = "video_metadata.json"
    private let videoDirectoryName = "videos"
    
    init() {
        createVideoDirectory()
        loadVideos()
    }
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var videoDirectory: URL {
        documentsDirectory.appendingPathComponent(videoDirectoryName)
    }
    
    private var metaFileUrl: URL {
        documentsDirectory.appendingPathComponent(metaFileName)
    }
    
    private func createVideoDirectory() {
        if !FileManager.default.fileExists(atPath: videoDirectory.path) {
            try? FileManager.default.createDirectory(at: videoDirectory, withIntermediateDirectories: true)
        }
    }
    
    func loadVideos() {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let data = try Data(contentsOf: metaFileUrl)
            let storedVideos = try JSONDecoder().decode([VideoStep].self, from: data)
            
            // Verify files actually exist
            var validVideos: [VideoStep] = []
            for video in storedVideos {
                if let url = video.fullURL, FileManager.default.fileExists(atPath: url.path) {
                    validVideos.append(video)
                }
            }
            
            self.videos = validVideos.sorted { $0.stepNumber < $1.stepNumber }
            
            // Update storage if files were missing
            if validVideos.count != storedVideos.count {
                saveVideosToDisk()
            }
        } catch {
            print("No saved videos found or error loading: \(error)")
            self.videos = []
        }
    }
    
    func addVideo(step: Int, sourceURL: URL, originalName: String) async throws {
        // 1. Generate unique filename
        let fileExt = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension
        let newFileName = "step_\(step)_\(Int(Date().timeIntervalSince1970)).\(fileExt)"
        let destinationURL = videoDirectory.appendingPathComponent(newFileName)
        
        // 2. Remove existing video for this step if it exists
        if let existingIndex = videos.firstIndex(where: { $0.stepNumber == step }) {
            await removeVideo(at: existingIndex)
        }
        
        // 3. Secure Copy (Accessing security scoped resources if needed)
        let secured = sourceURL.startAccessingSecurityScopedResource()
        defer { if secured { sourceURL.stopAccessingSecurityScopedResource() } }
        
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        
        // 4. Update Model
        let newStep = VideoStep(
            id: UUID().uuidString,
            stepNumber: step,
            relativePath: "\(videoDirectoryName)/\(newFileName)",
            originalName: originalName
        )
        
        videos.append(newStep)
        videos.sort { $0.stepNumber < $1.stepNumber }
        saveVideosToDisk()
    }
    
    func removeVideo(step: Int) async {
        if let index = videos.firstIndex(where: { $0.stepNumber == step }) {
            await removeVideo(at: index)
        }
    }
    
    private func removeVideo(at index: Int) async {
        let video = videos[index]
        if let url = video.fullURL {
            try? FileManager.default.removeItem(at: url)
        }
        videos.remove(at: index)
        saveVideosToDisk()
    }
    
    private func saveVideosToDisk() {
        do {
            let data = try JSONEncoder().encode(videos)
            try data.write(to: metaFileUrl)
        } catch {
            print("Error saving metadata: \(error)")
        }
    }
    
    func getVideo(for step: Int) -> VideoStep? {
        videos.first(where: { $0.stepNumber == step })
    }
}
