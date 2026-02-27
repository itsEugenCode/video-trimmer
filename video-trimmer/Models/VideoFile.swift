//
//  VideoFile.swift
//  video-trimmer
//
//  Created by Eugen on 25.02.2026.
//

import Foundation
import AVFoundation

// MARK: - Модели

/// Модель видеофайла
struct VideoFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let duration: TimeInterval
    let size: Int64
    let width: Int
    let height: Int
    let frameRate: Float
    var isValid: Bool
    var errorMessage: String?

    var fileName: String {
        url.lastPathComponent
    }

    var formattedDuration: String {
        duration.formatted
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var resolution: String {
        "\(width)x\(height)"
    }
}

/// Результат обрезки видео
struct TrimResult: Identifiable {
    let id = UUID()
    let originalFile: VideoFile
    let success: Bool
    let outputURL: URL?
    let errorMessage: String?
    let originalDuration: TimeInterval
    let newDuration: TimeInterval?

    init(success: Bool,
         originalFile: VideoFile,
         outputURL: URL? = nil,
         errorMessage: String? = nil,
         newDuration: TimeInterval? = nil) {
        self.success = success
        self.originalFile = originalFile
        self.outputURL = outputURL
        self.errorMessage = errorMessage
        self.originalDuration = originalFile.duration
        self.newDuration = newDuration
    }
}

/// Статус обработки
enum ProcessingStatus: Equatable, Hashable {
    case pending
    case processing
    case completed
    case failed(String)

    var description: String {
        switch self {
        case .pending: return "Ожидает"
        case .processing: return "Обработка..."
        case .completed: return "Готово"
        case .failed(let error): return "Ошибка: \(error)"
        }
    }
}

/// Настройки обрезки
struct TrimSettings: Equatable {
    var startTime: TimeInterval = 0
    var endTime: TimeInterval = 0

    var duration: TimeInterval {
        endTime - startTime
    }

    mutating func setFullDuration(_ duration: TimeInterval) {
        startTime = 0
        endTime = duration
    }

    mutating func setStartTime(_ time: TimeInterval, maxDuration: TimeInterval) {
        let clampedTime = max(0, min(time, maxDuration))
        let newEnd = clampedTime + Constants.minTrimDuration

        if newEnd > maxDuration {
            startTime = maxDuration - Constants.minTrimDuration
            endTime = maxDuration
        } else if newEnd > endTime {
            startTime = clampedTime
            endTime = newEnd
        } else {
            startTime = clampedTime
        }
    }

    mutating func setEndTime(_ time: TimeInterval, maxDuration: TimeInterval) {
        let clampedTime = max(Constants.minTrimDuration, min(time, maxDuration))
        let newStart = clampedTime - Constants.minTrimDuration

        if newStart < 0 {
            startTime = 0
            endTime = Constants.minTrimDuration
        } else if newStart < startTime {
            endTime = clampedTime
            startTime = newStart
        } else {
            endTime = clampedTime
        }
    }

    func isValid(for duration: TimeInterval) -> Bool {
        startTime >= 0 &&
        endTime <= duration &&
        endTime > startTime &&
        self.duration >= Constants.minTrimDuration
    }
}

// MARK: - Константы и утилиты

enum Constants {
    static let maxFileSize: Int64 = 1073741824 // 1 GB
    static let maxDuration: TimeInterval = 7200 // 120 минут
    static let supportedFormats = ["mp4", "mov", "avi", "mkv", "m4v"]

    static let minTrimDuration: TimeInterval = 0.1 // 100 мс

    static let skipDuration: TimeInterval = 0.333 // 1/3 секунды
    static let minDragDuration: TimeInterval = 0.1

    static let defaultOutputFilename = "trimmed_video"
    
    /// Стандартный timescale для CMTime (600 единиц в секунду)
    static let timeScale: CMTimeScale = 600
}

extension TimeInterval {
    var formatted: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var formattedTime: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        let milliseconds = Int((self.truncatingRemainder(dividingBy: 1)) * 1000)

        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
        }
    }
}

extension URL {
    var isSupportedVideoFormat: Bool {
        let ext = pathExtension.lowercased()
        return Constants.supportedFormats.contains(ext)
    }

    var fileExtension: String {
        pathExtension.lowercased()
    }
}
