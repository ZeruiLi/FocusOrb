import Foundation
import IOKit
import IOKit.hid
import CoreGraphics

protocol IdleTimeProviding {
    func idleSeconds() -> TimeInterval
}

final class SystemIdleTimeProvider: IdleTimeProviding {
    func idleSeconds() -> TimeInterval {
        if let seconds = readHIDIdleSeconds() {
            return seconds
        }
        return fallbackIdleSecondsViaCoreGraphics()
    }

    private func readHIDIdleSeconds() -> TimeInterval? {
        let matching = IOServiceMatching("IOHIDSystem")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        let key = "HIDIdleTime" as CFString
        guard let idleTimeRef = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return nil
        }

        let idleNanoseconds: UInt64?
        if let number = idleTimeRef as? NSNumber {
            idleNanoseconds = number.uint64Value
        } else if let data = idleTimeRef as? Data, data.count >= MemoryLayout<UInt64>.size {
            idleNanoseconds = data.withUnsafeBytes { $0.load(as: UInt64.self) }
        } else {
            idleNanoseconds = nil
        }

        guard let ns = idleNanoseconds else { return nil }
        return TimeInterval(Double(ns) / 1_000_000_000.0)
    }

    private func fallbackIdleSecondsViaCoreGraphics() -> TimeInterval {
        let sourceState: CGEventSourceStateID = .combinedSessionState
        let candidates: [CGEventType] = [
            .mouseMoved,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .scrollWheel,
            .keyDown,
            .flagsChanged
        ]

        let seconds = candidates
            .map { CGEventSource.secondsSinceLastEventType(sourceState, eventType: $0) }
            .min()

        return seconds ?? 0
    }
}

