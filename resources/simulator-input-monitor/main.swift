import Foundation
import Cocoa
import ApplicationServices

struct MonitorEvent: Codable {
    let kind: String
    let x: Double
    let y: Double
    let timestampMs: Double
}

struct WindowBoundsEvent: Codable {
    let kind: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

final class InputMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pointerDownAt: (x: Double, y: Double, time: Double)?
    private var boundsTimer: Timer?

    func start() -> Bool {
        let mask = (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.scrollWheel.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<InputMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            fputs("{\"kind\":\"error\",\"message\":\"event tap unavailable — grant Accessibility permission to Patrol Studio\"}\n", stderr)
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func isSimulatorFrontmost() -> Bool {
        NSWorkspace.shared.frontmostApplication?.localizedName == "Simulator"
    }

    private func simulatorWindowBounds() -> (x: Double, y: Double, width: Double, height: Double)? {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        for window in list {
            guard let owner = window[kCGWindowOwnerName as String] as? String, owner == "Simulator" else { continue }
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let bounds = window[kCGWindowBounds as String] as? [String: Any] else { continue }
            guard let x = bounds["X"] as? Double,
                  let y = bounds["Y"] as? Double,
                  let width = bounds["Width"] as? Double,
                  let height = bounds["Height"] as? Double,
                  width > 0, height > 0 else { continue }
            return (x, y, width, height)
        }
        return nil
    }

    private func emitBounds() {
        guard let bounds = simulatorWindowBounds() else { return }
        let encoder = JSONEncoder()
        let event = WindowBoundsEvent(kind: "windowBounds", x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height)
        guard let data = try? encoder.encode(event), let line = String(data: data, encoding: .utf8) else { return }
        print(line)
        fflush(stdout)
    }

    private func emit(_ event: MonitorEvent) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(event), let line = String(data: data, encoding: .utf8) else { return }
        print(line)
        fflush(stdout)
    }

    private func handle(type: CGEventType, event: CGEvent) {
        guard isSimulatorFrontmost() else { return }

        let location = event.location
        let timestampMs = Date().timeIntervalSince1970 * 1000

        switch type {
        case .leftMouseDown:
            pointerDownAt = (Double(location.x), Double(location.y), timestampMs)
            emit(MonitorEvent(kind: "mouseDown", x: Double(location.x), y: Double(location.y), timestampMs: timestampMs))
        case .leftMouseDragged:
            emit(MonitorEvent(kind: "mouseDrag", x: Double(location.x), y: Double(location.y), timestampMs: timestampMs))
        case .leftMouseUp:
            emit(MonitorEvent(kind: "mouseUp", x: Double(location.x), y: Double(location.y), timestampMs: timestampMs))
            pointerDownAt = nil
        case .scrollWheel:
            emit(MonitorEvent(kind: "scrollWheel", x: Double(location.x), y: Double(location.y), timestampMs: timestampMs))
        default:
            break
        }
    }

    func run() {
        boundsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.emitBounds()
        }
        RunLoop.main.run()
    }
}

let monitor = InputMonitor()
guard monitor.start() else {
    exit(1)
}
monitor.run()
