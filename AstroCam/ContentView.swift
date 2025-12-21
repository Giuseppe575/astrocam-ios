import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: CameraViewModel

    var body: some View {
        ZStack {
            CameraPreviewView(session: viewModel.session)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                TopOverlayView()
                Spacer()
                ControlPanelView()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}

struct TopOverlayView: View {
    @EnvironmentObject var viewModel: CameraViewModel

    var body: some View {
        HStack(spacing: 8) {
            ValuePill(title: "ISO", value: String(format: "%.0f", viewModel.iso))
            ValuePill(title: "Shutter", value: String(format: "%.1fs", viewModel.shutterSeconds))
            ValuePill(title: "Focus", value: String(format: "%.2f", viewModel.focusPosition))
            ValuePill(title: "WB", value: viewModel.whiteBalanceAuto ? "Auto" : String(format: "%.0fK", viewModel.whiteBalanceKelvin))
            ValuePill(title: "Format", value: viewModel.captureFormatLabel)
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ControlPanelView: View {
    @EnvironmentObject var viewModel: CameraViewModel

    var body: some View {
        VStack(spacing: 16) {
            PresetPickerView()

            ControlRow(title: "ISO", value: String(format: "%.0f", viewModel.iso)) {
                Slider(
                    value: Binding(
                        get: { Double(viewModel.iso) },
                        set: { viewModel.updateISO(Float($0)) }
                    ),
                    in: Double(viewModel.isoRange.lowerBound)...Double(viewModel.isoRange.upperBound)
                )
            }

            ControlRow(title: "Shutter", value: String(format: "%.1fs", viewModel.shutterSeconds)) {
                Slider(
                    value: Binding(
                        get: { viewModel.shutterSeconds },
                        set: { viewModel.updateShutter($0) }
                    ),
                    in: viewModel.shutterRange
                )
            }

            FocusControlView()

            VStack(spacing: 8) {
                HStack {
                    Text("WB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("Auto", isOn: Binding(
                        get: { viewModel.whiteBalanceAuto },
                        set: { viewModel.toggleAutoWhiteBalance($0) }
                    ))
                    .labelsHidden()
                }
                Slider(
                    value: Binding(
                        get: { Double(viewModel.whiteBalanceKelvin) },
                        set: { viewModel.updateWhiteBalance(Float($0)) }
                    ),
                    in: 3200...5000
                )
                .disabled(viewModel.whiteBalanceAuto)
            }

            HStack(spacing: 12) {
                ToggleButton(title: "AE Lock", isOn: viewModel.aeLocked) {
                    viewModel.toggleAELock()
                }
                ToggleButton(title: "AF Lock", isOn: viewModel.afLocked) {
                    viewModel.toggleAFLock()
                }
                Spacer()
                CaptureButton {
                    viewModel.capturePhoto()
                }
            }

            IntervalometerView()

            if let status = viewModel.statusMessage {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct PresetPickerView: View {
    @EnvironmentObject var viewModel: CameraViewModel

    var body: some View {
        VStack(spacing: 6) {
            Text("Preset")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Preset", selection: Binding(
                get: { viewModel.selectedPreset },
                set: { viewModel.applyPreset($0) }
            )) {
                ForEach(CameraPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct FocusControlView: View {
    @EnvironmentObject var viewModel: CameraViewModel

    var body: some View {
        ControlRow(title: "Focus", value: String(format: "%.2f", viewModel.focusPosition)) {
            HStack(spacing: 10) {
                Slider(
                    value: Binding(
                        get: { Double(viewModel.focusPosition) },
                        set: { viewModel.updateFocus(Float($0)) }
                    ),
                    in: 0...1
                )
                Button("INF") {
                    viewModel.setInfinityFocus()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct IntervalometerView: View {
    @EnvironmentObject var viewModel: CameraViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Intervallometro")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.intervalRunning {
                    Text(String(format: "%.1fs", viewModel.intervalCountdown))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                Stepper(value: $viewModel.intervalTotalShots, in: 1...999) {
                    Text("N: \(viewModel.intervalTotalShots)")
                        .font(.footnote)
                }
                Spacer()
                Stepper(value: $viewModel.intervalSeconds, in: 1...60, step: 1) {
                    Text("t: \(Int(viewModel.intervalSeconds))s")
                        .font(.footnote)
                }
            }
            HStack(spacing: 12) {
                Button(viewModel.intervalRunning ? "Stop" : "Start") {
                    if viewModel.intervalRunning {
                        viewModel.stopIntervalometer()
                    } else {
                        viewModel.startIntervalometer()
                    }
                }
                .buttonStyle(.borderedProminent)

                if viewModel.intervalRunning {
                    Text("Restanti: \(viewModel.intervalShotsRemaining)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }
}

struct ControlRow<Content: View>: View {
    let title: String
    let value: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            content
        }
    }
}

struct ToggleButton: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isOn ? Color.green.opacity(0.3) : Color.secondary.opacity(0.15))
                .clipShape(Capsule())
        }
    }
}

struct CaptureButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 54, height: 54)
                Circle()
                    .stroke(Color.black.opacity(0.2), lineWidth: 2)
                    .frame(width: 56, height: 56)
            }
        }
    }
}

struct ValuePill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

#Preview {
    ContentView()
        .environmentObject(CameraViewModel())
}

