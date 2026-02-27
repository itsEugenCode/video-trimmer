//
//  video_trimmerApp.swift
//  video-trimmer
//
//  Created by Eugen on 25.02.2026.
//

import SwiftUI

@main
struct video_trimmerApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .onReceive(NotificationCenter.default.publisher(for: .togglePlay)) { _ in
                    print("🔔 [App] Получено уведомление togglePlay")
                }
        }
        .windowStyle(.automatic)
        .commands {
            // Добавляем горячие клавиши
            CommandGroup(replacing: .newItem) {
                Button("Открыть файл...") {
                    NotificationCenter.default.post(name: .openFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Обрезать видео") {
                    NotificationCenter.default.post(name: .trimVideo, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandMenu("Воспроизведение") {
                Button("Воспроизведение/Пауза") {
                    print("🔔 [App] Menu: Воспроизведение/Пауза нажата")
                    NotificationCenter.default.post(name: .togglePlay, object: nil)
                }
                .keyboardShortcut(.space, modifiers: [])

                Divider()

                Button("Назад 1/3 сек") {
                    NotificationCenter.default.post(name: .skipBack, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: .shift)

                Button("Вперёд 1/3 сек") {
                    NotificationCenter.default.post(name: .skipForward, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: .shift)

                Divider()

                Button("Установить START") {
                    NotificationCenter.default.post(name: .setStart, object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Установить END") {
                    NotificationCenter.default.post(name: .setEnd, object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openFile = Notification.Name("openFile")
    static let trimVideo = Notification.Name("trimVideo")
    static let togglePlay = Notification.Name("togglePlay")
    static let skipBack = Notification.Name("skipBack")
    static let skipForward = Notification.Name("skipForward")
    static let setStart = Notification.Name("setStart")
    static let setEnd = Notification.Name("setEnd")
}
