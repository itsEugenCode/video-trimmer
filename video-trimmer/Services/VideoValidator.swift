//
//  VideoValidator.swift
//  video-trimmer
//
//  Created by Eugen on 25.02.2026.
//

import Foundation

/// Сервис валидации настроек обрезки
class VideoValidator {
    enum ValidationResult {
        case valid
        case invalid(String)

        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }

        var errorMessage: String? {
            if case .invalid(let message) = self { return message }
            return nil
        }
    }

    /// Валидация настроек обрезки для видеофайла
    func validateTrimSettings(_ settings: TrimSettings, for videoFile: VideoFile) -> ValidationResult {
        guard videoFile.isValid else {
            return .invalid(videoFile.errorMessage ?? "Невалидный видеофайл")
        }

        guard settings.startTime >= 0 else {
            return .invalid("Время начала не может быть отрицательным")
        }

        guard settings.endTime <= videoFile.duration else {
            return .invalid("Время окончания превышает длительность видео")
        }

        guard settings.endTime > settings.startTime else {
            return .invalid("Время окончания должно быть больше времени начала")
        }

        guard settings.duration >= Constants.minTrimDuration else {
            return .invalid("Минимальная длительность обрезки: \(Constants.minTrimDuration) сек")
        }

        return .valid
    }

    /// Валидация времени начала
    func validateStartTime(_ time: TimeInterval, for videoFile: VideoFile) -> ValidationResult {
        guard time >= 0 else {
            return .invalid("Время не может быть отрицательным")
        }

        guard time < videoFile.duration else {
            return .invalid("Время превышает длительность видео")
        }

        return .valid
    }

    /// Валидация времени окончания
    func validateEndTime(_ time: TimeInterval, for videoFile: VideoFile) -> ValidationResult {
        guard time > 0 else {
            return .invalid("Время должно быть больше нуля")
        }

        guard time <= videoFile.duration else {
            return .invalid("Время превышает длительность видео")
        }

        return .valid
    }
}
