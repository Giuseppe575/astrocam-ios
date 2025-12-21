import Foundation

enum CameraPreset: String, CaseIterable, Identifiable {
    case stars = "Stelle"
    case milkyWayUrban = "Via Lattea urbano"
    case milkyWayDark = "Via Lattea buio"

    var id: String { rawValue }

    var iso: Float {
        switch self {
        case .stars:
            return 800
        case .milkyWayUrban:
            return 1600
        case .milkyWayDark:
            return 3200
        }
    }

    var shutterSeconds: Double {
        switch self {
        case .stars:
            return 2.0
        case .milkyWayUrban:
            return 8.0
        case .milkyWayDark:
            return 15.0
        }
    }

    var whiteBalanceKelvin: Float {
        switch self {
        case .stars:
            return 3800
        case .milkyWayUrban:
            return 4200
        case .milkyWayDark:
            return 4000
        }
    }

    var intervalShots: Int {
        switch self {
        case .stars:
            return 20
        case .milkyWayUrban:
            return 60
        case .milkyWayDark:
            return 30
        }
    }

    var intervalSeconds: Double {
        switch self {
        case .stars:
            return 4.0
        case .milkyWayUrban:
            return 6.0
        case .milkyWayDark:
            return 5.0
        }
    }
}
