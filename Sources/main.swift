import AppKit
import GameController

final class BatteryApp: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var connectionIDs: [ObjectIdentifier: String] = [:]
    private var connectionNumbers: [String: Int] = [:]
    private var nameCounts: [String: Int] = [:]
    private var displayMode: String {
        UserDefaults.standard.string(forKey: "displayMode") ?? "automatic"
    }
    private var selectedName: String {
        UserDefaults.standard.string(forKey: "selectedControllerName") ?? "Selected controller"
    }
    private func readings(for connected: [GCController]) -> [ControllerReading] {
        let active = Set(connected.map { ObjectIdentifier($0) })
        connectionIDs = connectionIDs.filter { active.contains($0.key) }
        return connected.map { controller in
            let objectID = ObjectIdentifier(controller)
            let name = controller.vendorName ?? "Controller"
            if connectionIDs[objectID] == nil {
                let id = UUID().uuidString
                connectionIDs[objectID] = id
                nameCounts[name, default: 0] += 1
                connectionNumbers[id] = nameCounts[name]!
            }
            let id = connectionIDs[objectID]!
            let number = connectionNumbers[id]!
            let label = "\(name) #\(number)"
            return ControllerReading(id: id, name: label, percent: percentage(controller.battery), charging: controller.battery?.batteryState == .charging)
        }
    }
    @objc private func selectController(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? String else { return }
        UserDefaults.standard.set(mode, forKey: "displayMode")
        if mode != "automatic" && mode != "lowest" {
            UserDefaults.standard.set(sender.title, forKey: "selectedControllerName")
        }
        refresh()
    }
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private let intervals = [5, 10, 30, 60, 300]
    private var checkingInterval: Int {
        let saved = UserDefaults.standard.integer(forKey: "checkingIntervalSeconds")
        return intervals.contains(saved) ? saved : 30
    }
    private func intervalLabel(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds) seconds" : "\(seconds / 60) minute\(seconds == 60 ? "" : "s")"
    }
    private func restartTimer() {
        timer?.invalidate()
        let replacement = Timer(timeInterval: TimeInterval(checkingInterval), repeats: true) { [weak self] _ in self?.refresh() }
        replacement.tolerance = min(5, Double(checkingInterval) * 0.1)
        RunLoop.main.add(replacement, forMode: .common)
        timer = replacement
    }
    @objc private func selectInterval(_ sender: NSMenuItem) {
        guard intervals.contains(sender.tag) else { return }
        UserDefaults.standard.set(sender.tag, forKey: "checkingIntervalSeconds")
        restartTimer()
        refresh()
    }
    private var observers: [NSObjectProtocol] = []
    private let checkOnly = CommandLine.arguments.contains("--check")

    func applicationDidFinishLaunching(_ notification: Notification) {
        GCController.shouldMonitorBackgroundEvents = true
        _ = GCController.controllers()
        if checkOnly {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                let values: [[String: Any]] = self.controllers.map { controller in
                    var value: [String: Any] = ["name": controller.vendorName ?? "Controller"]
                    if let battery = controller.battery {
                        value["level"] = battery.batteryLevel
                        value["state"] = battery.batteryState.rawValue
                    }
                    return value
                }
                if let data = try? JSONSerialization.data(withJSONObject: ["controllers": values, "checkingIntervalSeconds": self.checkingInterval, "displayMode": self.displayMode], options: [.prettyPrinted]),
                   let text = String(data: data, encoding: .utf8) { print(text) }
                NSApp.terminate(nil)
            }
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: "Controller battery")
            button.image?.isTemplate = true
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        }
        for name in [Notification.Name.GCControllerDidConnect, Notification.Name.GCControllerDidDisconnect] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self?.refresh() }
            })
        }
        restartTimer()
        refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.refresh() }
    }

    private var controllers: [GCController] {
        GCController.controllers().sorted {
            ($0.vendorName ?? "").localizedStandardCompare($1.vendorName ?? "") == .orderedAscending
        }
    }

    private func percentage(_ battery: GCDeviceBattery?) -> Int? {
        guard let level = battery?.batteryLevel, level.isFinite, level >= 0, level <= 1 else { return nil }
        return Int((level * 100).rounded())
    }

    private func description(_ controller: GCController) -> String {
        let name = controller.vendorName ?? "Controller"
        guard let value = percentage(controller.battery) else { return "\(name): battery unavailable" }
        let state: String
        switch controller.battery?.batteryState {
        case .charging: state = "charging"
        case .full: state = "fully charged"
        case .discharging: state = "on battery"
        default: state = "charging status unknown"
        }
        return "\(name): \(value)% · \(state)"
    }

    @objc private func refresh() {
        let connected = controllers
        let readings = readings(for: connected)
        let primary = selectedReading(readings, mode: displayMode)
        let value = primary?.percent
        let charging = primary?.charging == true
        statusItem?.button?.title = value.map { " \($0)%\(charging ? " ⚡︎" : "")" } ?? " —"
        let selectionLabel = displayMode == "automatic" ? "Automatic" : displayMode == "lowest" ? "Lowest Battery" : selectedName
        let selectionStatus = primary.map { "\($0.name): \($0.percent.map { "\($0)%" } ?? "battery unavailable")" }
            ?? (displayMode == "lowest" ? "No battery readings available" : displayMode == "automatic" ? "No controller connected" : "\(selectedName) disconnected — select it again after reconnecting")
        statusItem?.button?.toolTip = "\(selectionLabel)\n\(selectionStatus)"
        let menu = NSMenu()
        if connected.isEmpty {
            menu.addItem(withTitle: "No controller connected", action: nil, keyEquivalent: "")
        } else {
            for (controller, reading) in zip(connected, readings) {
                let details = description(controller).replacingOccurrences(of: controller.vendorName ?? "Controller", with: reading.name, options: .anchored)
                menu.addItem(withTitle: details, action: nil, keyEquivalent: "")
            }
        }
        menu.addItem(.separator())
        let selectionItem = menu.addItem(withTitle: "Show Battery For: \(selectionLabel)", action: nil, keyEquivalent: "")
        let selectionMenu = NSMenu()
        func addChoice(_ title: String, _ mode: String) {
            let option = selectionMenu.addItem(withTitle: title, action: #selector(selectController(_:)), keyEquivalent: "")
            option.target = self
            option.representedObject = mode
            option.state = displayMode == mode ? .on : .off
        }
        addChoice("Automatic (prefer DualSense)", "automatic")
        addChoice("Lowest Battery", "lowest")
        selectionMenu.addItem(.separator())
        for reading in readings { addChoice(reading.name, reading.id) }
        if displayMode != "automatic" && displayMode != "lowest" && primary == nil {
            let missing = selectionMenu.addItem(withTitle: "\(selectedName) — disconnected", action: nil, keyEquivalent: "")
            missing.state = .on
        }
        if readings.isEmpty {
            selectionMenu.addItem(withTitle: "No controllers connected", action: nil, keyEquivalent: "")
        }
        selectionMenu.addItem(.separator())
        selectionMenu.addItem(withTitle: "Reselect specific controllers after reconnecting", action: nil, keyEquivalent: "")
        selectionItem.submenu = selectionMenu
        let intervalItem = menu.addItem(withTitle: "Check Every: \(intervalLabel(checkingInterval))", action: nil, keyEquivalent: "")
        let intervalMenu = NSMenu()
        for seconds in intervals {
            let option = intervalMenu.addItem(withTitle: intervalLabel(seconds), action: #selector(selectInterval(_:)), keyEquivalent: "")
            option.tag = seconds
            option.target = self
            option.state = seconds == checkingInterval ? .on : .off
        }
        intervalItem.submenu = intervalMenu
        let refreshItem = menu.addItem(withTitle: "Refresh Now", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.isEnabled = !connected.isEmpty
        menu.addItem(.separator())
        let quitItem = menu.addItem(withTitle: "Quit DualSense Battery", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        statusItem?.menu = menu
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(refresh) {
            return !controllers.isEmpty
        }
        return true
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let delegate = BatteryApp()
application.delegate = delegate
application.run()
