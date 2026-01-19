import SwiftUI

struct LoadingView: View {
    @ObservedObject var videoManager: VideoManager
    @State private var progress: CGFloat = 0.0
    @State private var loadingText = "Preparing videos..."
    @State private var isReady = false
    @State private var navigateToPlayer = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                if !isReady {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                        .padding()
                }
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)
                
                Text(loadingText)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 4)
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule().fill(Color.white)
                            .frame(width: geo.size.width * progress)
                            .animation(.easeOut, value: progress)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 40)
                .padding(.top, 30)
                
                if isReady {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .heavy)
                        generator.impactOccurred()
                        navigateToPlayer = true
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.black)
                        .padding()
                        .padding(.horizontal, 20)
                        .background(Color.white)
                        .cornerRadius(30)
                    }
                    .padding(.top, 50)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToPlayer) {
            PlayerView(videoManager: videoManager)
        }
        .onAppear {
            runChecks()
        }
    }
    
    func runChecks() {
        Task {
            let total = videoManager.videos.count
            for (index, _) in videoManager.videos.enumerated() {
                try? await Task.sleep(nanoseconds: 300_000_000) // Fake processing time
                let current = CGFloat(index + 1)
                
                withAnimation {
                    progress = current / CGFloat(total)
                    loadingText = "Loading step \(index + 1) of \(total)..."
                }
            }
            
            withAnimation {
                loadingText = "Ready to play!"
                isReady = true
            }
        }
    }
}
