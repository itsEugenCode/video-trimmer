//
//  ProgressOverlayView.swift
//  video-trimmer
//
//  Created by Eugen on 25.02.2026.
//

import SwiftUI

struct ProgressOverlayView: View {
    @ObservedObject var viewModel: MainViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Заголовок
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "scissors")
                        .font(.title2)
                    Text("Обрезка видео")
                        .font(.headline)
                }

                Spacer()

                Button(action: {
                    viewModel.cancelTrimming()
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            // Прогресс
            VStack(spacing: 16) {
                // Статус и проценты
                HStack {
                    Text(viewModel.progress < 1 ? "Обработка..." : "Завершение...")
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(viewModel.progress * 100))%")
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(.accentColor)
                }

                // Прогресс-бар
                ProgressView(value: viewModel.progress)
                    .scaleEffect(y: 1.5, anchor: .center)

                // Детали
                HStack(spacing: 24) {
                    Label("Осталось времени: ~\(estimatedTimeRemaining) сек", systemImage: "clock")
                    Label("Скорость: N/A", systemImage: "gauge")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            // Информация о файлах
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Входной файл
                    HStack(spacing: 8) {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.accentColor)
                        Text(inputFileName)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }

                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)

                    // Выходной файл
                    HStack(spacing: 8) {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.green)
                        Text(viewModel.outputFileName)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            // Кнопка отмены
            if viewModel.isProcessing {
                Button(action: {
                    viewModel.cancelTrimming()
                    dismiss()
                }) {
                    Label("Отмена", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding(32)
        .frame(width: 500, height: 400)
    }

    private var inputFileName: String {
        viewModel.currentVideoFile?.fileName ?? "unknown"
    }

    private var estimatedTimeRemaining: Int {
        // Временная заглушка - расчёт будет добавлен позже
        return 0
    }
}
