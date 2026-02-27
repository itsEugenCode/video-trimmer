//
//  ControlRow.swift
//  video-trimmer
//
//  Created by Eugen on 25.02.2026.
//

import SwiftUI

struct ControlRow: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Левая сторона: время начала
            TimeTextField(
                value: viewModel.trimSettings.startTime,
                onValueChange: { viewModel.setStartTime($0) },
                disabled: !viewModel.canSetStartTime
            )
            
            // Кнопка START
            Button(action: {
                viewModel.setStartTimeToCurrentTime()
            }) {
                Label("START", systemImage: "flag.fill")
            }
            .disabled(!viewModel.canSetStartTime)
            .help("Установить время начала (Cmd+[)")
            
            // Кнопка Back
            Button(action: {
                viewModel.skipBackward()
            }) {
                Image(systemName: "backward.fill")
            }
            .disabled(!viewModel.canPlay)
            .help("Назад 1/3 сек (Shift+←)")
            
            // Кнопка Play/Pause (центр)
            Button(action: {
                print("🟢 [ControlRow] Play нажата!")
                viewModel.togglePlay()
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .disabled(!viewModel.canPlay)
            .help("Воспроизведение/Пауза (Space)")
            
            // Кнопка Forward
            Button(action: {
                viewModel.skipForward()
            }) {
                Image(systemName: "forward.fill")
            }
            .disabled(!viewModel.canPlay)
            .help("Вперёд 1/3 сек (Shift+→)")
            
            // Кнопка END
            Button(action: {
                viewModel.setEndTimeToCurrentTime()
            }) {
                Label("END", systemImage: "flag.fill")
            }
            .disabled(!viewModel.canSetEndTime)
            .help("Установить время окончания (Cmd+])")
            
            // Правая сторона: время конца
            TimeTextField(
                value: viewModel.trimSettings.endTime,
                onValueChange: { viewModel.setEndTime($0) },
                disabled: !viewModel.canSetEndTime
            )
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Time Text Field

struct TimeTextField: View {
    let value: TimeInterval
    let onValueChange: (TimeInterval) -> Void
    let disabled: Bool
    
    @State private var textValue: String = ""
    
    var body: some View {
        TextField("00:00:00.000", text: $textValue)
            .textFieldStyle(.roundedBorder)
            .frame(width: 140)
            .font(.system(.body, design: .monospaced))
            .disabled(disabled)
            .onChange(of: value) { newValue in
                textValue = newValue.formattedTime
            }
            .onAppear {
                textValue = value.formattedTime
            }
            .onSubmit {
                if let parsedTime = parseTimeText(textValue) {
                    onValueChange(parsedTime)
                }
            }
            .onExitCommand {
                if let parsedTime = parseTimeText(textValue) {
                    onValueChange(parsedTime)
                } else {
                    textValue = value.formattedTime
                }
            }
    }
    
    private func parseTimeText(_ text: String) -> TimeInterval? {
        let text = text.trimmingCharacters(in: .whitespaces)
        
        let components = text.split(separator: ":")
        var hours: Double = 0
        var minutes: Double = 0
        var seconds: Double = 0
        
        switch components.count {
        case 1:
            if let secs = Double(components[0]) {
                seconds = secs
            } else {
                return nil
            }
        case 2:
            if let mins = Double(components[0]),
               let secs = Double(components[1]) {
                minutes = mins
                seconds = secs
            } else {
                return nil
            }
        case 3:
            if let hrs = Double(components[0]),
               let mins = Double(components[1]),
               let secs = Double(components[2]) {
                hours = hrs
                minutes = mins
                seconds = secs
            } else {
                return nil
            }
        default:
            return nil
        }
        
        return hours * 3600 + minutes * 60 + seconds
    }
}
