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
            guard corePath() != nil else {
                result("missingCore")
                return
            }
            currentRom = rom
            result("running")
        case "stop", "pause", "resume", "reset", "input", "saveState", "deleteSaveSlot":
            result(nil)
        case "loadState":
            result("running")
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

    private func coreDir() -> URL {
        let dir = documentsDir().appendingPathComponent("cores")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func statesDir() -> URL {
        let dir = documentsDir().appendingPathComponent("states")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func corePath() -> String? {
        let files = try? FileManager.default.contentsOfDirectory(
            at: coreDir(), includingPropertiesForKeys: nil
        )
        return files?.first(where: { $0.pathExtension == "dylib" })?.path
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
