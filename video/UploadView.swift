import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct UploadView: View {
    @StateObject var videoManager = VideoManager()
    @State private var showingVideoPicker = false
    @State private var showingFilePicker = false
    @State private var selectedStepForUpload: Int?
    @State private var navigateToLoading = false
    
    // Haptics
    private let impactMed = UIImpactFeedbackGenerator(style: .medium)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
                LinearGradient(colors: [Color(hex: "0a0a0a"), Color(hex: "111111"), Color(hex: "1a1a1a")], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Header
                        HStack {
                            Image(systemName: "film.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                            Text("Video Steps")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        
                        Text("Upload your videos in sequence. They will play seamlessly as one continuous experience.")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.subheadline)
                        
                        // Progress Card
                        VStack(spacing: 12) {
                            HStack {
                                Text("Videos Uploaded")
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                Text("\(videoManager.videos.count) / \(videoManager.totalSteps)")
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.1))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green)
                                        .frame(width: geo.size.width * (CGFloat(videoManager.videos.count) / CGFloat(videoManager.totalSteps)))
                                        .animation(.spring(), value: videoManager.videos.count)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        
                        // Steps List
                        ForEach(1...videoManager.totalSteps, id: \.self) { step in
                            StepCard(
                                step: step,
                                video: videoManager.getVideo(for: step),
                                onUpload: {
                                    selectedStepForUpload = step
                                    promptForSource()
                                },
                                onRemove: {
                                    Task { await videoManager.removeVideo(step: step) }
                                    impactMed.impactOccurred()
                                }
                            )
                        }
                        
                        // Add Step Button
                        Button(action: {
                            videoManager.totalSteps += 1
                            impactLight.impactOccurred()
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Another Step")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    .foregroundColor(.white.opacity(0.2))
                            )
                            .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.top, 10)
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
                
                // Start Button
                if !videoManager.videos.isEmpty {
                    VStack {
                        Spacer()
                        Button(action: {
                            impactMed.impactOccurred()
                            navigateToLoading = true
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                    .foregroundColor(.black)
                                Text("Start Experience")
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient(colors: [.white, Color(uiColor: .systemGray5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationDestination(isPresented: $navigateToLoading) {
                LoadingView(videoManager: videoManager)
            }
            // Logic for Pickers
            .photosPicker(isPresented: $showingVideoPicker, selection: Binding(get: { nil }, set: { item in
                if let item = item {
                    loadVideoFromPicker(item: item)
                }
            }), matching: .videos)
            .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
                if let url = try? result.get().first {
                    handleFileImport(url: url)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // Helper to choose source
    func promptForSource() {
        let alert = UIAlertController(title: "Select Video Source", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Photos Library", style: .default) { _ in showingVideoPicker = true })
        alert.addAction(UIAlertAction(title: "Files", style: .default) { _ in showingFilePicker = true })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let controller = windowScene.windows.first?.rootViewController {
            controller.present(alert, animated: true)
        }
    }
    
    // Handle Photo Picker
    func loadVideoFromPicker(item: PhotosPickerItem) {
        item.loadTransferable(type: MovieFileTransferable.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let movie):
                    if let movie = movie, let step = selectedStepForUpload {
                        Task {
                            try? await videoManager.addVideo(step: step, sourceURL: movie.url, originalName: "Library Video")
                        }
                    }
                case .failure(let error):
                    print("Error: \(error)")
                }
            }
        }
    }
    
    // Handle File Import
    func handleFileImport(url: URL) {
        guard let step = selectedStepForUpload else { return }
        Task {
            try? await videoManager.addVideo(step: step, sourceURL: url, originalName: url.lastPathComponent)
        }
    }
}

// Wrapper for Photo Picker Transfer
struct MovieFileTransferable: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(received.file.lastPathComponent)
            try? FileManager.default.removeItem(at: copy) // Cleanup old
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
}

// UI Component
struct StepCard: View {
    let step: Int
    let video: VideoStep?
    let onUpload: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        Button(action: {
             if video == nil { onUpload() }
        }) {
            HStack(spacing: 16) {
                // Icon Circle
                ZStack {
                    Circle().fill(Color.white.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    if video != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 24))
                    } else {
                        Text("\(step)")
                            .foregroundColor(.white.opacity(0.6))
                            .fontWeight(.semibold)
                    }
                }
                
                // Text
                VStack(alignment: .leading) {
                    Text("Step \(step)")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                        .font(.title3)
                    
                    if let v = video {
                        Text(v.originalName)
                            .foregroundColor(.white.opacity(0.5))
                            .font(.caption)
                            .lineLimit(1)
                    } else {
                        Text("Tap to upload video")
                            .foregroundColor(.white.opacity(0.4))
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                // Action Button
                if video != nil {
                    Button(action: onRemove) {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay(Image(systemName: "trash").foregroundColor(.red).font(.system(size: 18)))
                    }
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)
                        .overlay(Image(systemName: "square.and.arrow.up").foregroundColor(.white.opacity(0.6)).font(.system(size: 18)))
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Color Hex Helper
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
