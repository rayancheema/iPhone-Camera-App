
import AVFoundation
import Photos
import UIKit
import Combine
import ObjectiveC

final class CameraManager: ObservableObject {

    let session = AVCaptureSession()

    @Published var isReady = false
    @Published var isRunning = false
    @Published var isTelephoto = false
    @Published var message = "Checking camera access…"

    var currentLensLabel: String {
        isTelephoto ? "2×" : "0.5×"
    }

    private let queue = DispatchQueue(label: "ultrawide.camera.queue")
    private let photoOutput = AVCapturePhotoOutput()

    private var configured = false
    private var isConfiguring = false
    private var isCapturing = false
    private var activePhotoDelegate: PhotoCaptureDelegate?

    // MARK: - Camera Permission

    func requestPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            start()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }

                DispatchQueue.main.async {
                    if granted {
                        self.start()
                    } else {
                        self.message = "Camera permission denied. Allow access in Settings."
                    }
                }
            }

        case .denied, .restricted:
            DispatchQueue.main.async {
                self.message = "Allow camera access in iPhone Settings."
            }

        @unknown default:
            DispatchQueue.main.async {
                self.message = "Unable to check camera permission."
            }
        }
    }

    // MARK: - Start Camera

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            guard !self.isConfiguring else { return }

            self.isConfiguring = true
            defer { self.isConfiguring = false }

            do {
                if !self.configured {
                    guard let device = AVCaptureDevice.default(
                        .builtInUltraWideCamera,
                        for: .video,
                        position: .back
                    ) else {
                        DispatchQueue.main.async {
                            self.message = "Ultra-wide camera unavailable."
                        }
                        return
                    }

                    let input = try AVCaptureDeviceInput(device: device)

                    self.session.beginConfiguration()
                    self.session.sessionPreset = .photo

                    guard self.session.canAddInput(input) else {
                        self.session.commitConfiguration()
                        DispatchQueue.main.async {
                            self.message = "Cannot add camera input."
                        }
                        return
                    }

                    guard self.session.canAddOutput(self.photoOutput) else {
                        self.session.commitConfiguration()
                        DispatchQueue.main.async {
                            self.message = "Cannot add photo output."
                        }
                        return
                    }

                    self.session.addInput(input)
                    self.session.addOutput(self.photoOutput)
                    self.session.commitConfiguration()

                    self.configured = true
                    self.isTelephoto = false
                }

                if !self.session.isRunning {
                    self.session.startRunning()
                }

                DispatchQueue.main.async {
                    self.isReady = true
                    self.isRunning = true
                    self.message = self.isTelephoto
                        ? "2× telephoto camera ready"
                        : "0.5× ultra-wide camera ready"
                }
            } catch {
                DispatchQueue.main.async {
                    self.isReady = false
                    self.isRunning = false
                    self.message = "Camera error: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Switch Between 0.5× and 2×

    func toggleLens() {
        queue.async { [weak self] in
            guard let self,
                  self.configured,
                  self.session.isRunning,
                  !self.isConfiguring,
                  !self.isCapturing else {
                return
            }

            self.isConfiguring = true
            defer { self.isConfiguring = false }

            let switchToTelephoto = !self.isTelephoto

            let deviceType: AVCaptureDevice.DeviceType =
                switchToTelephoto
                ? .builtInTelephotoCamera
                : .builtInUltraWideCamera

            guard let device = AVCaptureDevice.default(
                deviceType,
                for: .video,
                position: .back
            ) else {
                DispatchQueue.main.async {
                    self.message = "Requested camera is unavailable."
                }
                return
            }

            do {
                let newInput = try AVCaptureDeviceInput(device: device)

                self.session.beginConfiguration()

                let oldInputs = self.session.inputs.compactMap {
                    $0 as? AVCaptureDeviceInput
                }

                oldInputs.forEach {
                    self.session.removeInput($0)
                }

                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.session.commitConfiguration()

                    self.isTelephoto = switchToTelephoto

                    DispatchQueue.main.async {
                        self.message = switchToTelephoto
                            ? "2× telephoto camera ready"
                            : "0.5× ultra-wide camera ready"
                    }
                } else {
                    oldInputs.forEach {
                        if self.session.canAddInput($0) {
                            self.session.addInput($0)
                        }
                    }

                    self.session.commitConfiguration()

                    DispatchQueue.main.async {
                        self.message = "Could not switch camera."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.message = "Lens switch failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Stop Camera

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }

            if self.session.isRunning {
                self.session.stopRunning()
            }

            DispatchQueue.main.async {
                self.isRunning = false
                self.isReady = false
                self.message = "Camera stopped."
            }
        }
    }

    // MARK: - Capture Photo

    func takePhoto() {
        queue.async { [weak self] in
            guard let self,
                  self.configured,
                  self.session.isRunning,
                  !self.isCapturing else {
                DispatchQueue.main.async {
                    self?.message = "Camera is not ready or is already capturing."
                }
                return
            }

            self.isCapturing = true

            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off

            let delegate = PhotoCaptureDelegate { [weak self] result in
                guard let self else { return }

                switch result {
                case .success(let data):
                    self.savePhoto(data)

                case .failure(let error):
                    DispatchQueue.main.async {
                        self.message = "Capture failed: \(error.localizedDescription)"
                    }
                    self.finishCapture()
                }
            }

            self.activePhotoDelegate = delegate

            DispatchQueue.main.async {
                self.message = "Taking photo…"
            }

            self.photoOutput.capturePhoto(
                with: settings,
                delegate: delegate
            )
        }
    }

    private func finishCapture() {
        queue.async { [weak self] in
            guard let self else { return }
            self.isCapturing = false
            self.activePhotoDelegate = nil
        }
    }

    // MARK: - Save Photo to Photos Library

    private func savePhoto(_ data: Data) {
        guard UIImage(data: data) != nil else {
            DispatchQueue.main.async {
                self.message = "Captured image data is invalid."
            }
            finishCapture()
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            guard let self else { return }

            guard status == .authorized else {
                DispatchQueue.main.async {
                    self.message = "Photos access denied. Check iPhone Settings."
                }
                self.finishCapture()
                return
            }

            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(
                    with: .photo,
                    data: data,
                    options: nil
                )
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.message = "Photo saved to Photos!"
                    } else {
                        self.message = "Save failed: \(error?.localizedDescription ?? "Unknown error")"
                    }
                }

                self.finishCapture()
            }
        }
    }
}

// MARK: - Photo Capture Delegate

private final class PhotoCaptureDelegate: NSObject,
                                          AVCapturePhotoCaptureDelegate {

    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(
                NSError(
                    domain: "CameraApp",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "The camera did not return photo data."
                    ]
                )
            ))
            return
        }

        completion(.success(data))
    }
}
