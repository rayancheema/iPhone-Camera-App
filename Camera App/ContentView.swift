
import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Image(systemName: "camera.fill")
                        .font(.title2)

                    Text("UltraWide")
                        .font(.headline)

                    Spacer()

                    Circle()
                        .fill(cameraManager.isReady ? .green : .orange)
                        .frame(width: 8, height: 8)

                    Text(cameraManager.isReady ? "READY" : "STARTING")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 18)

                // Live camera preview
                ZStack {
                    CameraPreview(session: cameraManager.session)
                        .background(Color.black)

                    if !cameraManager.isReady {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)

                            Text(cameraManager.message)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(.black.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(24)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 12)
                .frame(maxHeight: .infinity)

                // Status message
                Text(cameraManager.message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Camera controls
                HStack {
                    // Lens switch
                    Button {
                        cameraManager.toggleLens()
                    } label: {
                        Text(cameraManager.currentLensLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 62, height: 62)
                            .background(.white.opacity(0.15))
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        .white.opacity(0.35),
                                        lineWidth: 1
                                    )
                            }
                    }
                    .disabled(!cameraManager.isReady)

                    Spacer()

                    // Shutter button
                    Button {
                        cameraManager.takePhoto()
                    } label: {
                        Circle()
                            .fill(.white)
                            .frame(width: 76, height: 76)
                            .overlay {
                                Circle()
                                    .strokeBorder(.white.opacity(0.65), lineWidth: 4)
                                    .padding(5)
                            }
                    }
                    .disabled(!cameraManager.isReady)

                    Spacer()

                    // Decorative lens indicator
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 25))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 62, height: 62)
                }
                .padding(.horizontal, 32)
                .padding(.top, 10)
                .padding(.bottom, 26)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            cameraManager.requestPermissionAndStart()
        }
        .onDisappear {
            cameraManager.stop()
        }
    }
}

// MARK: - Live Camera Preview

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

#Preview {
    ContentView()
}
