//
//  TrimActionSection.swift
//  video-trimmer
//
//  Created by Eugen on 25.02.2026.
//

import SwiftUI

struct TrimActionSection: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        HStack {
                // Информация о выходном файле
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .font(.title2)
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.outputFileName.isEmpty ? "trimmed_video.mp4" : viewModel.outputFileName)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                            Text("Сохранён в папку «Загрузки»")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Кнопка Обрезать
                if viewModel.isProcessing {
                    Button(action: {
                        viewModel.cancelTrimming()
                    }) {
                        Label("Отмена", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                } else {
                    Button(action: {
                        Task {
                            await viewModel.startTrimming()
                        }
                    }) {
                        Label("Обрезать", systemImage: "scissors")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canStartTrimming)
                    .help("Начать обрезку видео (Cmd+R)")
                }
            }
            .padding(.vertical, 8)
    }
}
