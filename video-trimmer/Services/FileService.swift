//
//  FileService.swift
//  video-trimmer
//
//  Created by Eugen on 26.02.2026.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Протокол FileService

protocol FileServiceProtocol {
    func selectFile(allowedContentTypes: [UTType]) async -> URL?
    func copyToAppContainer(url: URL, subfolder: String) async throws -> URL
    func getDownloadsFolder() throws -> URL
    func generateUniqueName(originalURL: URL, in folder: URL, preferredExtension: String?) -> URL
    func generateNameWithTimestamp(originalURL: URL, extension: String?) -> String
    func fileExists(at url: URL) -> Bool
    func removeFile(at url: URL) throws
}

// MARK: - Ошибки FileService

enum FileServiceError: Error, LocalizedError {
    case folderNotFound(String)
    case fileCopyFailed
    case downloadsFolderNotFound
    
    var errorDescription: String? {
        switch self {
        case .folderNotFound(let folder):
            return "Папка не найдена: \(folder)"
        case .fileCopyFailed:
            return "Не удалось скопировать файл"
        case .downloadsFolderNotFound:
            return "Папка загрузок недоступна"
        }
    }
}

// MARK: - Реализация FileService

final class FileService: FileServiceProtocol {

    // MARK: - Public свойства
    
    /// Папка загрузок (для App Sandbox)
    var downloadsFolder: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }

    // MARK: - Public методы

    @MainActor
    func selectFile(allowedContentTypes: [UTType]) async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = allowedContentTypes

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        return url
    }

    func copyToAppContainer(url: URL, subfolder: String) async throws -> URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw FileServiceError.folderNotFound("Application Support")
        }

        let targetFolder = appSupport.appendingPathComponent(subfolder, isDirectory: true)

        // Создаём папку если нет
        if !FileManager.default.fileExists(atPath: targetFolder.path) {
            try FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)
        }

        let localURL = targetFolder.appendingPathComponent(url.lastPathComponent)

        // Удаляем старый файл если есть (безопасно)
        if fileExists(at: localURL) {
            try? removeFile(at: localURL)
        }

        // Копируем файл
        do {
            try FileManager.default.copyItem(at: url, to: localURL)
            return localURL
        } catch {
            throw FileServiceError.fileCopyFailed
        }
    }
    
    func getDownloadsFolder() throws -> URL {
        guard let downloadsFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            throw FileServiceError.downloadsFolderNotFound
        }
        return downloadsFolder
    }
    
    func generateUniqueName(originalURL: URL, in folder: URL, preferredExtension: String?) -> URL {
        let originalName = originalURL.deletingPathExtension().lastPathComponent
        let baseName = "\(originalName)_trimmed"
        // Используем preferredExtension если задан и не пуст, иначе оригинальное расширение
        let extensionName = preferredExtension?.isEmpty == false
            ? preferredExtension!
            : originalURL.pathExtension

        var counter = 0
        var finalName = baseName
        var finalURL = folder.appendingPathComponent("\(finalName).\(extensionName)")

        let maxAttempts = 1000
        while fileExists(at: finalURL) && counter < maxAttempts {
            counter += 1
            finalName = "\(baseName)_\(counter)"
            finalURL = folder.appendingPathComponent("\(finalName).\(extensionName)")
        }

        return finalURL
    }

    func generateNameWithTimestamp(originalURL: URL, `extension`: String?) -> String {
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let ext = `extension`?.isEmpty == false
            ? `extension`!
            : originalURL.pathExtension
        let timestamp = Date().formatted(.dateTime.year().month().day().hour().minute().second())
        return "\(baseName)_trimmed_\(timestamp).\(ext)"
    }

    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func removeFile(at url: URL) throws {
        guard fileExists(at: url) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
