@preconcurrency import AVFoundation
import BuddyCore
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

/// The cameras on this Mac, as plain values for Settings and `CameraChoice`.
public enum CameraDevices {
    /// Built-in, USB or display cameras, and an iPhone (Continuity Camera). The Desk View camera is left out.
    public static func available() -> [CameraInfo] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.map { CameraInfo(id: $0.uniqueID, name: $0.localizedName, kind: kind(of: $0)) }
    }

    /// The device for the user's pick, or the best one when the pick is gone.
    static func device(savedID: String?) -> AVCaptureDevice? {
        guard let choice = CameraChoice.pick(savedID: savedID, from: available()) else {
            return AVCaptureDevice.default(for: .video)
        }
        return AVCaptureDevice(uniqueID: choice.id)
    }

    private static func kind(of device: AVCaptureDevice) -> CameraInfo.Kind {
        switch device.deviceType {
        case .builtInWideAngleCamera: .builtIn
        case .continuityCamera: .continuity
        default: .external
        }
    }
}

/// Work on one camera frame. Each call runs on the camera queue and keeps nothing.
enum CameraFrames {
    /// A face, or the shape of a head and shoulders, is in the frame.
    static func personVisible(in pixelBuffer: CVPixelBuffer) -> Bool {
        let faces = VNDetectFaceRectanglesRequest()
        let people = VNDetectHumanRectanglesRequest()
        people.upperBodyOnly = true
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        guard (try? handler.perform([faces, people])) != nil else { return false }
        let faceFound = !(faces.results ?? []).isEmpty
        let personFound = (people.results ?? []).contains { $0.confidence >= 0.5 }
        return faceFound || personFound
    }

    /// The frame as a mirrored JPEG (like a mirror, as people expect to see themselves).
    /// Privacy: the file holds only pixels. No camera name, place or time is written into it.
    static func jpeg(from pixelBuffer: CVPixelBuffer, context: CIContext, quality: Double = 0.8) -> Data? {
        let image = CIImage(cvPixelBuffer: pixelBuffer).oriented(.upMirrored)
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return nil }
        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
