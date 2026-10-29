import Foundation
func reading(_ id: String, _ name: String, _ level: Int?, _ charging: Bool = false) -> ControllerReading {
    ControllerReading(id: id, name: name, percent: level, charging: charging)
}
let a = reading("a", "DualSense #1", 65)
let b = reading("b", "DualSense #2", 20, true)
let c = reading("c", "Other Controller", nil)
assert(selectedReading([a,b,c], mode: "lowest")?.id == "b")
assert(selectedReading([a,b,c], mode: "a")?.percent == 65)
assert(selectedReading([b,c], mode: "a") == nil)
assert(selectedReading([c], mode: "lowest") == nil)
assert(selectedReading([], mode: "lowest") == nil)
assert(selectedReading([c,a], mode: "automatic")?.id == "a")
assert(selectedReading([a,reading("b", "DualSense #2", 80)], mode: "lowest")?.id == "a")
assert(selectedReading([reading("zero", "Controller", 0),a], mode: "lowest")?.id == "zero")
print("Passed: individual selection, duplicate names, disconnection, lowest level changes, charging, unknown levels, empty list, zero battery, automatic mode.")
