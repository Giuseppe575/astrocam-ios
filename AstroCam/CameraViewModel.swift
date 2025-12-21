import AVFoundation
import Foundation
import SwiftUI
import UIKit

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var iso: Float = 100
    @Published var isoRange: ClosedRange<Float> = 50...1600
    @Published var shutterSeconds: Double = 1.0
    @Published var shutterRange: ClosedRange<Double> = 0.1...30.0
    @Published var focusPosition: Float = 0.5
    @Published var whiteBalanceKelvin: Float = 4000
    @Published var whiteBalanceAuto = true
    @Published var aeLocked = false
    @Published var afLocked = false
    @Published var captureFormatLabel = "HEIF"
    @Published var statusMessage: String?

    @Published var intervalRunning = false
    @Published var intervalShotsRemaining = 0
    @Published var intervalCountdown = 0.0
    @Published var intervalTotalShots = 10
    @Published var intervalSeconds = 5.0

    @Published var selectedPreset: CameraPreset = .stars

    var session: AVCaptureSession {
        cameraService.session
    }

    private let cameraService = CameraService()
    private var intervalTask: Task<Void, Never>?
    private var isConfigured = false

    func start() {
        Task {
            let cameraGranted = await requestCameraPermission()
            if !cameraGranted {
                statusMessage = "Camera permission denied."
                return
            }

            PhotoLibrary.shared.requestAddPermission { granted in
                if !granted {
                    self.statusMessage = "Photo library permission denied."
                }
            }

            if !isConfigured {
                configureSession()
            }

            UIApplication.shared.isIdleTimerDisabled = true
            cameraService.startRunning()
        }
    }

    func stop() {
        cameraService.stopRunning()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func applyPreset(_ preset: CameraPreset) {
        selectedPreset = preset
        iso = preset.iso
        shutterSeconds = preset.shutterSeconds
        whiteBalanceKelvin = preset.whiteBalanceKelvin
        whiteBalanceAuto = false
        intervalTotalShots = preset.intervalShots
        intervalSeconds = preset.intervalSeconds
        applyManualSettings()
    }

    func updateISO(_ value: Float) {
        iso = value
        if !aeLocked {
            cameraService.setExposure(iso: iso, durationSeconds: shutterSeconds)
        }
    }

    func updateShutter(_ value: Double) {
        shutterSeconds = value
        if !aeLocked {
            cameraService.setExposure(iso: iso, durationSeconds: shutterSeconds)
        }
    }

    func updateFocus(_ value: Float) {
        focusPosition = value
        cameraService.setFocus(lensPosition: focusPosition)
        afLocked = true
        cameraService.setAFLocked(true)
    }

    func setInfinityFocus() {
        updateFocus(1.0)
    }

    func updateWhiteBalance(_ value: Float) {
        whiteBalanceKelvin = value
        if !whiteBalanceAuto {
            cameraService.setWhiteBalance(auto: false, temperature: whiteBalanceKelvin)
        }
    }

    func toggleAutoWhiteBalance(_ enabled: Bool) {
        whiteBalanceAuto = enabled
        cameraService.setWhiteBalance(auto: enabled, temperature: whiteBalanceKelvin)
    }

    func toggleAELock() {
        aeLocked.toggle()
        cameraService.setAELocked(aeLocked)
    }

    func toggleAFLock() {
        afLocked.toggle()
        cameraService.setAFLocked(afLocked)
    }

    func capturePhoto() {
        statusMessage = "Cattura in corso..."
        cameraService.capturePhoto { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.statusMessage = "Scatto salvato in AstroCam."
                case .failure(let error):
                    self?.statusMessage = "Errore scatto: \(error.localizedDescription)"
                }
            }
        }
    }

    func startIntervalometer() {
        guard !intervalRunning else { return }
        intervalRunning = true
        intervalShotsRemaining = intervalTotalShots

        intervalTask?.cancel()
        intervalTask = Task { [weak self] in
            guard let self = self else { return }

            for shotIndex in 0..<self.intervalTotalShots {
                if Task.isCancelled { break }
                await MainActor.run {
                    self.statusMessage = "Scatto \(shotIndex + 1) di \(self.intervalTotalShots)"
                }

                await MainActor.run {
                    self.capturePhoto()
                    self.intervalShotsRemaining = self.intervalTotalShots - shotIndex - 1
                }

                if shotIndex < self.intervalTotalShots - 1 {
                    await self.runCountdown(seconds: self.intervalSeconds)
                }
            }

            await MainActor.run {
                self.intervalCountdown = 0
                self.intervalRunning = false
            }
        }
    }

    func stopIntervalometer() {
        intervalTask?.cancel()
        intervalTask = nil
        intervalRunning = false
        intervalCountdown = 0
        statusMessage = "Intervallometro fermato."
    }

    private func runCountdown(seconds: Double) async {
        let tick: Double = 0.1
        var remaining = seconds
        await MainActor.run {
            self.intervalCountdown = remaining
        }

        while remaining > 0 && !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(tick * 1_000_000_000))
            remaining = max(0, remaining - tick)
            await MainActor.run {
                self.intervalCountdown = remaining
            }
        }
    }

    private func configureSession() {
        cameraService.configure { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let capabilities):
                self.isConfigured = true
                self.isoRange = capabilities.isoRange
                let minExposure = max(0.1, capabilities.minExposureSeconds)
                let maxExposure = min(30.0, capabilities.maxExposureSeconds)
                self.shutterRange = minExposure...maxExposure
                self.iso = min(max(self.iso, capabilities.isoRange.lowerBound), capabilities.isoRange.upperBound)
                self.shutterSeconds = min(max(self.shutterSeconds, self.shutterRange.lowerBound), self.shutterRange.upperBound)
                self.captureFormatLabel = capabilities.supportsRaw ? "RAW" : "HEIF"
                self.applyManualSettings()
            case .failure(let error):
                self.statusMessage = "Errore configurazione: \(error.localizedDescription)"
            }
        }
    }

    private func applyManualSettings() {
        cameraService.setExposure(iso: iso, durationSeconds: shutterSeconds)
        cameraService.setFocus(lensPosition: focusPosition)
        cameraService.setWhiteBalance(auto: whiteBalanceAuto, temperature: whiteBalanceKelvin)
    }

    private func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }
}
