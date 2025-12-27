import AVFoundation
import Foundation

struct DeviceCapabilities {
    let isoRange: ClosedRange<Float>
    let minExposureSeconds: Double
    let maxExposureSeconds: Double
    let supportsRaw: Bool
}

enum CameraServiceError: Error {
    case missingDevice
    case cannotAddInput
    case cannotAddOutput
    case cannotProcessPhoto
}

final class CameraService: NSObject {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "astrocam.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var photoCaptureCompletion: ((Result<Void, Error>) -> Void)?
    private(set) var supportsRawCapture = false

    func configure(completion: @escaping (Result<DeviceCapabilities, Error>) -> Void) {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    completion(.failure(CameraServiceError.missingDevice))
                }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.videoDeviceInput = input
                } else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async {
                        completion(.failure(CameraServiceError.cannotAddInput))
                    }
                    return
                }
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.isHighResolutionCaptureEnabled = true
            } else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    completion(.failure(CameraServiceError.cannotAddOutput))
                }
                return
            }

            self.supportsRawCapture = !self.photoOutput.availableRawPhotoPixelFormatTypes.isEmpty

            let minExposure = device.activeFormat.minExposureDuration.seconds
            let maxExposure = device.activeFormat.maxExposureDuration.seconds
            let isoRange = device.activeFormat.minISO...device.activeFormat.maxISO

            self.session.commitConfiguration()

            let capabilities = DeviceCapabilities(
                isoRange: isoRange,
                minExposureSeconds: minExposure,
                maxExposureSeconds: maxExposure,
                supportsRaw: self.supportsRawCapture
            )

            DispatchQueue.main.async {
                completion(.success(capabilities))
            }
        }
    }

    func startRunning() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stopRunning() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func setExposure(iso: Float, durationSeconds: Double) {
        sessionQueue.async {
            guard let device = self.videoDeviceInput?.device else { return }
            let clampedISO = min(max(iso, device.activeFormat.minISO), device.activeFormat.maxISO)
            let clampedSeconds = min(max(durationSeconds, device.activeFormat.minExposureDuration.seconds), device.activeFormat.maxExposureDuration.seconds)
            let duration = CMTimeMakeWithSeconds(clampedSeconds, preferredTimescale: 1_000_000_000)

            do {
                try device.lockForConfiguration()
                device.setExposureModeCustom(duration: duration, iso: clampedISO, completionHandler: nil)
                device.unlockForConfiguration()
            } catch {
                return
            }
        }
    }

    func setAELocked(_ locked: Bool) {
        sessionQueue.async {
            guard let device = self.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if locked {
                    let duration = device.exposureDuration
                    let iso = device.iso
                    device.setExposureModeCustom(duration: duration, iso: iso, completionHandler: nil)
                } else if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            } catch {
                return
            }
        }
    }

    func setFocus(lensPosition: Float) {
        sessionQueue.async {
            guard let device = self.videoDeviceInput?.device else { return }
            let clamped = min(max(lensPosition, 0.0), 1.0)
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.locked) {
                    device.setFocusModeLocked(lensPosition: clamped, completionHandler: nil)
                }
                device.unlockForConfiguration()
            } catch {
                return
            }
        }
    }

    func setAFLocked(_ locked: Bool) {
        sessionQueue.async {
            guard let device = self.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if locked {
                    if device.isFocusModeSupported(.locked) {
                        device.setFocusModeLocked(lensPosition: device.lensPosition, completionHandler: nil)
                    }
                } else if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                device.unlockForConfiguration()
            } catch {
                return
            }
        }
    }

    func setWhiteBalance(auto: Bool, temperature: Float) {
        sessionQueue.async {
            guard let device = self.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if auto {
                    if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                        device.whiteBalanceMode = .continuousAutoWhiteBalance
                    }
                } else if device.isWhiteBalanceModeSupported(.locked) {
                    let tempAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: temperature, tint: 0)
                    var gains = device.deviceWhiteBalanceGains(for: tempAndTint)
                    let maxGain = device.maxWhiteBalanceGain
                    gains.redGain = min(max(gains.redGain, 1.0), maxGain)
                    gains.greenGain = min(max(gains.greenGain, 1.0), maxGain)
                    gains.blueGain = min(max(gains.blueGain, 1.0), maxGain)
                    device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                }
                device.unlockForConfiguration()
            } catch {
                return
            }
        }
    }

    func capturePhoto(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            self.photoCaptureCompletion = completion

            let settings: AVCapturePhotoSettings
            if self.supportsRawCapture,
               let rawType = self.photoOutput.availableRawPhotoPixelFormatTypes.first {
                settings = AVCapturePhotoSettings(rawPixelFormatType: rawType)
            } else if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                settings = AVCapturePhotoSettings()
            }

            settings.isHighResolutionPhotoEnabled = true
            if #available(iOS 13.0, *) {
                settings.photoQualityPrioritization = .quality
            }

            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let completion = photoCaptureCompletion else { return }
        photoCaptureCompletion = nil

        if let error = error {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            DispatchQueue.main.async {
                completion(.failure(CameraServiceError.cannotProcessPhoto))
            }
            return
        }

        PhotoLibrary.shared.savePhotoData(data) { result in
            completion(result)
        }
    }
}
