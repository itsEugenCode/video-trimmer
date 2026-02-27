//
//  VideoScanner.swift
//  video-trimmer
//
//  Created by Eugen on 25.02.2026.
//

import Foundation
import AVFoundation

/// Сервис для сканирования и получения информации о видеофайлах
class VideoScanner {
    /// Получить информацию о видеофайле
    func getVideoInfo(from url: URL) async throws -> VideoFile {
        let asset = AVURLAsset(url: url)

        // Загружаем необходимые свойства
        let duration = try await asset.load(.duration)
        let fileSize = try await getFileSize(for: url)
        let tracks = try await asset.load(.tracks)

        let durationSeconds = CMTimeGetSeconds(duration)

        // Получаем информацию о видео треке
        let videoTrack = tracks.first { $0.mediaType == .video }
        let width: Int
        let height: Int
        let frameRate: Float

        if let videoTrack = videoTrack {
            let size = try await videoTrack.load(.naturalSize)
            let transform = try await videoTrack.load(.preferredTransform)

            // Учитываем ориентацию видео
            let isPortrait = transform.b < 0 || transform.c < 0
            width = Int(isPortrait ? size.height : size.width)
            height = Int(isPortrait ? size.width : size.height)

            // Получаем frame rate
            let minFrameDuration = try await videoTrack.load(.minFrameDuration)
            frameRate = minFrameDuration.timescale > 0
                ? Float(minFrameDuration.value) / Float(minFrameDuration.timescale)
                : 30.0
        } else {
            width = 0
            height = 0
            frameRate = 0
        }

        // Валидация
        let isValid = validateVideo(
            duration: durationSeconds,
            size: fileSize,
            width: width,
            height: height
        )

        var errorMessage: String?
        if !isValid {
            if durationSeconds > Constants.maxDuration {
                errorMessage = "Длительность превышает лимит (\(Constants.maxDuration / 60) мин)"
            } else if Double(fileSize) > Double(Constants.maxFileSize) {
                errorMessage = "Размер превышает лимит (1 GB)"
            } else if width == 0 || height == 0 {
                errorMessage = "Не удалось определить разрешение видео"
            }
        }

        return VideoFile(
            url: url,
            duration: durationSeconds,
            size: fileSize,
            width: width,
            height: height,
            frameRate: frameRate,
            isValid: isValid,
            errorMessage: errorMessage
        )
    }

    /// Получить размер файла
    private func getFileSize(for url: URL) async throws -> Int64 {
        let resources = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(resources.fileSize ?? 0)
    }

    /// Валидация видео
    private func validateVideo(duration: TimeInterval, size: Int64, width: Int, height: Int) -> Bool {
        guard duration > 0 && duration <= Constants.maxDuration else { return false }
        guard Double(size) <= Double(Constants.maxFileSize) else { return false }
        guard width > 0 && height > 0 else { return false }
        return true
    }
}
