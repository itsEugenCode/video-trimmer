//
//  FileNamingService.swift
//  video-trimmer
//
//  Created by Eugen on 26.02.2026.
//

import Foundation

/// Сервис для генерации уникальных имён файлов
final class FileNamingService {
    /// Сгенерировать уникальное имя для выходного файла
    func generateUniqueName(originalURL: URL, in folder: URL, preferredExtension: String? = nil) -> URL {
        let originalName = originalURL.deletingPathExtension().lastPathComponent
        let baseName = "\(originalName)_trimmed"
        let extensionName = preferredExtension ?? originalURL.pathExtension
        
        var counter = 0
        var finalName = baseName
        var finalURL = folder.appendingPathComponent("\(finalName).\(extensionName)")
        
        while FileManager.default.fileExists(atPath: finalURL.path) {
            counter += 1
            finalName = "\(baseName)_\(counter)"
            finalURL = folder.appendingPathComponent("\(finalName).\(extensionName)")
        }
        
        return finalURL
    }
    
    /// Сгенерировать имя файла с таймштампом
    func generateNameWithTimestamp(originalURL: URL, `extension`: String? = nil) -> String {
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        // Используем extension если задан и не пуст, иначе оригинальное расширение
        let ext = `extension`?.isEmpty == false
            ? `extension`!
            : originalURL.pathExtension
        let timestamp = Date().formatted(.dateTime.year().month().day().hour().minute().second())
        return "\(baseName)_trimmed_\(timestamp).\(ext)"
    }
}
