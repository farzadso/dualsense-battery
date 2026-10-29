import Foundation

struct ControllerReading {
    let id: String
    let name: String
    let percent: Int?
    let charging: Bool
}

func selectedReading(_ readings: [ControllerReading], mode: String) -> ControllerReading? {
    switch mode {
    case "lowest":
        return readings.filter { $0.percent != nil }.min { $0.percent! < $1.percent! }
    case "automatic":
        return readings.first { $0.name.localizedCaseInsensitiveContains("DualSense") } ?? readings.first
    default:
        return readings.first { $0.id == mode }
    }
}
