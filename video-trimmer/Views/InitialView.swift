//
//  InitialView.swift
//  video-trimmer
//
//  Created by Eugen on 25.02.2026.
//

import SwiftUI

struct InitialView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Фон всей зоны
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [10])
                    )
                    .foregroundColor(isDragging ? .accentColor : .gray)
                    .opacity(0.5)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .foregroundColor(Color(NSColor.windowBackgroundColor))
                    )

                // Контент по центру
                VStack(spacing: 20) {
                    // Иконка
                    Image(systemName: "video.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)

                    // Заголовок
                    Text("Video Trimmer")
                        .font(.title)
                        .fontWeight(.bold)

                    // Подзаголовок
                    Text("Обрезка видео")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Основной текст
                    Text("Нажмите сюда для выбора файла")
                        .font(.body)
                        .foregroundColor(.secondary)

                    // Разделитель
                    HStack {
                        Line()
                            .frame(width: 80)
                        Text("или")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Line()
                            .frame(width: 80)
                    }
                    .padding(.vertical, 4)

                    // Текст о drag & drop
                    Text("перетащите файл сюда")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(40)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Task {
                    await viewModel.selectFile()
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                handleDrop(providers: providers)
                return true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleDrop(providers: [NSItemProvider]) {
        viewModel.handleDropFromProviders(providers)
    }
}

// MARK: - Line Helper

struct Line: View {
    var body: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(.gray)
            .opacity(0.5)
    }
}

#Preview {
    InitialView(viewModel: MainViewModel())
}
