//
//  VideoTrimmerEngine.swift
//  video-trimmer
//
//  Created by Eugen on 26.02.2026.
//

import Foundation
import AVFoundation

// MARK: - Протокол TrimService

/// Протокол для обрезки видео
/// - Предоставляет метод для обрезки видео по заданному временному диапазону
/// - Поддерживает отмену операции обрезки
protocol TrimServiceProtocol {
    func trim(videoFile: VideoFile, settings: TrimSettings, outputURL: URL) async throws -> TrimResult
    func cancel()
}

// MARK: - Ошибки TrimService

enum TrimServiceError: Error, LocalizedError {
    case exportSessionCreationFailed
    case exportFailed(Error?)
    case downloadsFolderNotFound
    
    var errorDescription: String? {
        switch self {
        case .exportSessionCreationFailed:
            return "Не удалось создать сессию экспорта"
        case .exportFailed(let error):
            return error?.localizedDescription ?? "Ошибка при экспорте видео"
        case .downloadsFolderNotFound:
            return "Папка загрузок недоступна"
        }
    }
}

// MARK: - Реализация VideoTrimmerEngine

final class VideoTrimmerEngine: TrimServiceProtocol {
    private var exportSession: AVAssetExportSession?

    private let fileService: FileServiceProtocol
    
    init(fileService: FileServiceProtocol = FileService()) {
        self.fileService = fileService
    }
    
    /// Обрезать видео
    /// outputURL должен быть в папке Downloads (App Sandbox)
    func trim(
        videoFile: VideoFile,
        settings: TrimSettings,
        outputURL: URL
    ) async throws -> TrimResult {
        // Создаём ассет из исходного файла (локальная копия в App Container)
        let asset = AVURLAsset(url: videoFile.url)

        // Создаём сессию экспорта
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw TrimServiceError.exportSessionCreationFailed
        }

        exportSession = session

        // Настраиваем временной диапазон
        let startTime = CMTime(seconds: settings.startTime, preferredTimescale: Constants.timeScale)
        let duration = CMTime(seconds: settings.duration, preferredTimescale: Constants.timeScale)
        session.timeRange = CMTimeRange(start: startTime, duration: duration)

        // Настраиваем выходной файл (outputURL уже в Downloads)
        session.outputURL = outputURL
        session.outputFileType = AVFileType.mp4
        session.shouldOptimizeForNetworkUse = true

        // Запускаем экспорт
        await session.export()

        if session.status == .completed {
            // Файл сохранён в Downloads
            // Получаем длительность результата
            let outputAsset = AVURLAsset(url: outputURL)
            let outputDuration = try? await outputAsset.load(.duration)

            return TrimResult(
                success: true,
                originalFile: videoFile,
                outputURL: outputURL,
                newDuration: outputDuration.map { CMTimeGetSeconds($0) }
            )
        } else if session.status == .cancelled {
            return TrimResult(
                success: false,
                originalFile: videoFile,
                outputURL: nil,
                errorMessage: "Обрезка отменена"
            )
        } else {
            return TrimResult(
                success: false,
                originalFile: videoFile,
                outputURL: nil,
                errorMessage: session.error?.localizedDescription ?? "Неизвестная ошибка"
            )
        }
    }
    
    /// Отменить обрезку
    func cancel() {
        exportSession?.cancelExport()
    }
}
