import BuddyCore
import CoreAudio
import Foundation

/// Thin read-only wrappers around the CoreAudio C API. Nothing here opens an audio stream or reads sound.
enum AudioHardware {
    private static let system = AudioObjectID(kAudioObjectSystemObject)

    /// Every app that runs audio input now, as plain values. Nil if macOS does not answer.
    /// Process objects exist from macOS 14.2.
    @available(macOS 14.2, *)
    static func inputClients() -> [AudioInputClient]? {
        guard let processes = objectList(system, kAudioHardwarePropertyProcessObjectList) else { return nil }
        return processes.compactMap { process in
            guard let isRunning: UInt32 = scalar(process, kAudioProcessPropertyIsRunningInput), isRunning != 0,
                let pid: pid_t = scalar(process, kAudioProcessPropertyPID)
            else { return nil }
            let inputDevices = objectList(process, kAudioProcessPropertyDevices, scope: kAudioObjectPropertyScopeInput)
            return AudioInputClient(
                pid: pid,
                bundleID: string(process, kAudioProcessPropertyBundleID),
                isRunningInput: true,
                inputDeviceCount: inputDevices?.count ?? 0
            )
        }
    }

    /// True if any device that has a microphone (input streams) runs for some app.
    /// Used before macOS 14.2. It cannot tell which app, so it also counts our own use (we have none).
    static func anyInputDeviceIsRunning() -> Bool {
        let devices = objectList(system, kAudioHardwarePropertyDevices) ?? []
        return devices.contains { device in
            guard hasInputStreams(device) else { return false }
            let running: UInt32? = scalar(device, kAudioDevicePropertyDeviceIsRunningSomewhere)
            return (running ?? 0) != 0
        }
    }

    private static func hasInputStreams(_ device: AudioObjectID) -> Bool {
        let streams = objectList(device, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
        return !(streams ?? []).isEmpty
    }

    // MARK: - CoreAudio property reads

    private static func propertyAddress(
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func objectList(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> [AudioObjectID]? {
        var address = propertyAddress(selector, scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr else { return nil }
        let stride = MemoryLayout<AudioObjectID>.stride
        guard size >= stride else { return [] }

        var ids = [AudioObjectID](repeating: AudioObjectID(kAudioObjectUnknown), count: Int(size) / stride)
        let status = ids.withUnsafeMutableBytes { buffer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, buffer.baseAddress!)
        }
        guard status == noErr else { return nil }
        // The list can shrink between the two calls; `size` now holds the real length.
        return Array(ids.prefix(Int(size) / stride))
    }

    private static func scalar<T: FixedWidthInteger>(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector
    ) -> T? {
        var address = propertyAddress(selector, kAudioObjectPropertyScopeGlobal)
        var value: T = 0
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer)
        }
        return status == noErr ? value : nil
    }

    /// CoreAudio hands back a retained CFString; `takeRetainedValue` balances it.
    private static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = propertyAddress(selector, kAudioObjectPropertyScopeGlobal)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer)
        }
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}
