import Flutter
import UIKit
import GameController

final class EmulatorPlugin: NSObject {
    static let emulatorChannel = "org.renanprojects.n64/emulator"
    static let controllersChannel = "org.renanprojects.n64/controllers"
    static let surfaceViewType = "org.renanprojects.n64/surface"

    private let host = EmulatorHost()

    func register(with registrar: FlutterPluginRegistrar) {
        let methods = FlutterMethodChannel(
            name: EmulatorPlugin.emulatorChannel,
            binaryMessenger: registrar.messenger()
        )
        methods.setMethodCallHandler { [weak self] call, result in
            self?.host.handle(call, result: result)
        }

        let events = FlutterEventChannel(
            name: EmulatorPlugin.controllersChannel,
            binaryMessenger: registrar.messenger()
        )
        events.setStreamHandler(ControllerObserver())

        registrar.register(
            EmulatorViewFactory(host: host),
            withId: EmulatorPlugin.surfaceViewType
        )
    }
}

final class EmulatorHost {
    private var currentRom: String?

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isCoreAvailable":
            result(corePath() != nil)
        case "controllerCount":
            result(GCController.controllers().count)
        case "start":
            guard let args = call.arguments as? [String: Any],
                  let rom = args["rom"] as? String else {
                result("error")
                return
            }
            guard let core = corePath() else {
                result("missingCore")
                return
            }
            currentRom = rom
            n64_set_paths(core, rom, systemDir().path, saveDir().path)
            result("running")
        case "stop":
            n64_pause(true)
            currentRom = nil
            result(nil)
        case "pause":
            n64_pause(true)
            result(nil)
        case "resume":
            n64_pause(false)
            result(nil)
        case "reset":
            n64_reset()
            result(nil)
        case "input":
            let args = call.arguments as? [String: Any]
            let buttons = (args?["buttons"] as? Int) ?? 0
            let sx = Float((args?["stickX"] as? Double) ?? 0)
            let sy = Float((args?["stickY"] as? Double) ?? 0)
            n64_set_input(Int32(buttons), sx, sy)
            result(nil)
        case "saveState":
            let slot = (call.arguments as? [String: Any])?["slot"] as? Int ?? 0
            if let file = slotFile(currentRom, slot) { n64_save_state(file.path) }
            result(nil)
        case "loadState":
            let slot = (call.arguments as? [String: Any])?["slot"] as? Int ?? 0
            if let file = slotFile(currentRom, slot),
               FileManager.default.fileExists(atPath: file.path) {
                _ = n64_load_state(file.path)
                result("running")
            } else {
                result("error")
            }
        case "deleteSaveSlot":
            let args = call.arguments as? [String: Any]
            let slot = args?["slot"] as? Int ?? 0
            if let file = slotFile(args?["rom"] as? String, slot) {
                try? FileManager.default.removeItem(at: file)
            }
            result(nil)
        case "saveSlots":
            let rom = (call.arguments as? [String: Any])?["rom"] as? String
            result(listSlots(rom))
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func documentsDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func statesDir() -> URL {
        let dir = documentsDir().appendingPathComponent("states")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func systemDir() -> URL {
        let dir = documentsDir().appendingPathComponent("system")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func saveDir() -> URL {
        let dir = documentsDir().appendingPathComponent("saves")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func corePath() -> String? {
        Bundle.main.path(forResource: "mupen64plus_next", ofType: "dylib")
    }

    private func slotFile(_ rom: String?, _ slot: Int) -> URL? {
        guard let rom = rom else { return nil }
        let name = (rom as NSString).lastPathComponent
        let base = (name as NSString).deletingPathExtension
        return statesDir().appendingPathComponent("\(base).state\(slot)")
    }

    private func listSlots(_ rom: String?) -> [[String: Any?]] {
        guard let rom = rom else { return [] }
        let name = (rom as NSString).lastPathComponent
        let base = (name as NSString).deletingPathExtension
        var slots: [[String: Any?]] = []
        for i in 0..<10 {
            let file = statesDir().appendingPathComponent("\(base).state\(i)")
            let exists = FileManager.default.fileExists(atPath: file.path)
            let attrs = try? FileManager.default.attributesOfItem(atPath: file.path)
            slots.append([
                "index": i,
                "isAuto": false,
                "filePath": exists ? file.path : nil,
                "modified": exists
                    ? Int((attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0) * 1000
                    : nil,
                "sizeBytes": exists ? (attrs?[.size] as? Int) : nil,
            ])
        }
        return slots
    }
}

final class ControllerObserver: NSObject, FlutterStreamHandler {
    private var sink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        NotificationCenter.default.addObserver(
            self, selector: #selector(changed),
            name: .GCControllerDidConnect, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(changed),
            name: .GCControllerDidDisconnect, object: nil
        )
        emit()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(self)
        sink = nil
        return nil
    }

    @objc private func changed() {
        emit()
    }

    private func emit() {
        sink?(GCController.controllers().count)
    }
}
