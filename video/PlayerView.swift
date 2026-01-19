import SwiftUI
import AVKit

struct PlayerView: View {
    @ObservedObject var videoManager: VideoManager
    @State private var currentIndex = 0
    @State private var players: [AVPlayer] = []
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // We layer players. Only the active one is visible and playing.
            // The next one is paused but ready (buffered).
            ForEach(0..<players.count, id: \.self) { index in
                VideoPlayerContainer(player: players[index])
                    .opacity(index == currentIndex ? 1 : 0)
                    .ignoresSafeArea()
            }
        }
        .onTapGesture {
            advanceVideo()
        }
        .onAppear {
            setupPlayers()
        }
        .navigationBarBackButtonHidden(true)
    }
    
    func setupPlayers() {
        // Pre-create players for all videos
        players = videoManager.videos.compactMap { step in
            guard let url = step.fullURL else { return nil }
            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            player.actionAtItemEnd = .pause // Stop at end, don't loop
            return player
        }
        
        // Start first video
        if let first = players.first {
            first.play()
        }
    }
    
    func advanceVideo() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Pause current
        if currentIndex < players.count {
            players[currentIndex].pause()
        }
        
        let nextIndex = currentIndex + 1
        
        // Check if finished
        if nextIndex >= players.count {
            // End of experience
            // In a real app, you might want to pop back to root.
            // For now, we just reset or exit.
            // Using NotificationCenter to pop to root is a common SwiftUI trick,
            // or we could inject a dismissing binding.
            // For this snippet, we'll just loop back to start for demo purposes
            // or stop. Let's just stop.
            return
        }
        
        // Play next
        currentIndex = nextIndex
        players[currentIndex].seek(to: .zero)
        players[currentIndex].play()
    }
}

// Simple wrapper for AVPlayerLayer to get rid of standard controls
struct VideoPlayerContainer: UIViewControllerRepresentable {
    var player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }
}
