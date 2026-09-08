import Foundation
import Vapor
import VeilShared

struct ProcessedImage: Sendable {
    let data: Data
    let width: Int
    let height: Int
    let mimeType: String
}

protocol ImageProcessing: Sendable {
    func sanitize(data: Data, declaredWidth: Int, declaredHeight: Int, mimeType: String) async throws -> ProcessedImage
}

struct VipsImageProcessor: ImageProcessing {
    let temporaryDirectory: URL

    func sanitize(data: Data, declaredWidth: Int, declaredHeight: Int, mimeType: String) async throws -> ProcessedImage {
        guard data.count <= VeilValidation.maximumImageBytes,
              declaredWidth > 0,
              declaredHeight > 0,
              declaredWidth <= VeilValidation.maximumImageDimension,
              declaredHeight <= VeilValidation.maximumImageDimension,
              declaredWidth * declaredHeight <= VeilValidation.maximumImagePixels,
              ["image/jpeg", "image/png", "image/heic", "image/webp"].contains(mimeType.lowercased()) else {
            throw APIError.invalidInput("Image dimensions, size, or type are unsupported")
        }

        let operationID = UUID().uuidString
        let input = self.temporaryDirectory.appendingPathComponent("\(operationID).input")
        let output = self.temporaryDirectory.appendingPathComponent("\(operationID).jpg")
        try data.write(to: input, options: .atomic)
        defer {
            try? FileManager.default.removeItem(at: input)
            try? FileManager.default.removeItem(at: output)
        }

        let actualWidth = try self.dimension(named: "width", for: input)
        let actualHeight = try self.dimension(named: "height", for: input)
        guard actualWidth == declaredWidth,
              actualHeight == declaredHeight,
              actualWidth <= VeilValidation.maximumImageDimension,
              actualHeight <= VeilValidation.maximumImageDimension,
              actualWidth * actualHeight <= VeilValidation.maximumImagePixels else {
            throw APIError.invalidInput("Image dimensions do not match the upload")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/vips")
        process.arguments = ["thumbnail", input.path, "\(output.path)[strip]", "2400", "--size", "down"]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw APIError.invalidInput("Image decoding failed")
        }
        guard process.terminationStatus == 0, let outputData = try? Data(contentsOf: output), !outputData.isEmpty else {
            throw APIError.invalidInput("Image decoding failed")
        }
        let scale = min(1.0, 2_400.0 / Double(max(actualWidth, actualHeight)))
        return ProcessedImage(
            data: outputData,
            width: max(1, Int(Double(actualWidth) * scale)),
            height: max(1, Int(Double(actualHeight) * scale)),
            mimeType: "image/jpeg"
        )
    }

    private func dimension(named field: String, for input: URL) throws -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/vipsheader")
        process.arguments = ["-f", field, input.path]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw APIError.invalidInput("Image decoding failed")
        }
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let value = Int(text), value > 0 else {
            throw APIError.invalidInput("Image decoding failed")
        }
        return value
    }
}

struct ImageProcessorKey: StorageKey { typealias Value = any ImageProcessing }

extension Application {
    var imageProcessor: any ImageProcessing {
        get {
            guard let value = self.storage[ImageProcessorKey.self] else { fatalError("Image processor not configured") }
            return value
        }
        set { self.storage[ImageProcessorKey.self] = newValue }
    }
}
