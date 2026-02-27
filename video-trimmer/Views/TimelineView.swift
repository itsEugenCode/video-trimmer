//
//  TimelineView.swift
//  video-trimmer
//
//  Created by Eugen on 25.02.2026.
//

import SwiftUI

struct TimelineView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 8) {
                // Timeline трек
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Фон трека
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 44)
                            .cornerRadius(6)

                        // Прогресс воспроизведения
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.3))
                            .frame(
                                width: progressWidth(geometry: geometry),
                                height: 44
                            )
                            .cornerRadius(6)

                        // Диапазон обрезки
                        trimRangeView(geometry: geometry)

                        // Текущая позиция
                        currentPositionView(geometry: geometry)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                // Если перетаскивание было коротким — считаем это кликом
                                if value.translation.width < 5 && value.translation.height < 5 {
                                    handleTimelineClick(location: value.location.x, geometry: geometry)
                                }
                            }
                    )
                }
                .frame(height: 44)

                // Подписи времени
                HStack {
                    // Время начала
                    Text(viewModel.trimSettings.startTime.formattedTime)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Текущее время воспроизведения
                    Text(viewModel.currentTime.formattedTime)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    // Время окончания
                    Text(viewModel.trimSettings.endTime.formattedTime)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
    }

    // MARK: - Trim Range View

    @ViewBuilder
    private func trimRangeView(geometry: GeometryProxy) -> some View {
        let range = trimRange(geometry: geometry)

        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.5))
                .frame(
                    width: max(0, range.end - range.start),
                    height: 44
                )
                .offset(x: range.start)

            // Handle начала (START)
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 4, height: 44)
                .cornerRadius(2)
                .offset(x: range.start)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleStartDrag(value: value, geometry: geometry)
                        }
                )
                .onHover { hovering in
                    if hovering {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                }

            // Handle конца (END)
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 4, height: 44)
                .cornerRadius(2)
                .offset(x: range.end - 4)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleEndDrag(value: value, geometry: geometry)
                        }
                )
                .onHover { hovering in
                    if hovering {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        }
    }

    // MARK: - Current Position View

    @ViewBuilder
    private func currentPositionView(geometry: GeometryProxy) -> some View {
        let position = currentPositionX(geometry: geometry)

        Rectangle()
            .fill(Color.white)
            .frame(width: 2, height: 44)
            .shadow(color: .black, radius: 2)
            .offset(x: position - 1)
    }

    // MARK: - Helpers

    private func progressWidth(geometry: GeometryProxy) -> CGFloat {
        guard let duration = viewModel.currentVideoFile?.duration,
              duration > 0 else { return 0 }
        let percent = CGFloat(viewModel.currentTime / duration)
        return geometry.size.width * percent
    }

    private func trimRange(geometry: GeometryProxy) -> (start: CGFloat, end: CGFloat) {
        guard let duration = viewModel.currentVideoFile?.duration,
              duration > 0 else { return (0, 0) }

        let startPercent = CGFloat(viewModel.trimSettings.startTime / duration)
        let endPercent = CGFloat(viewModel.trimSettings.endTime / duration)

        return (
            start: startPercent * geometry.size.width,
            end: endPercent * geometry.size.width
        )
    }

    private func currentPositionX(geometry: GeometryProxy) -> CGFloat {
        guard let duration = viewModel.currentVideoFile?.duration,
              duration > 0 else { return 0 }

        let percent = CGFloat(viewModel.currentTime / duration)
        return percent * geometry.size.width
    }

    // MARK: - Drag Handlers

    private func handleTimelineClick(location: CGFloat, geometry: GeometryProxy) {
        guard let duration = viewModel.currentVideoFile?.duration,
              duration > 0 else { return }

        // Точный расчет позиции с учетом границ
        let clampedLocation = max(0, min(location, geometry.size.width))
        let percent = clampedLocation / geometry.size.width
        let time = percent * duration

        // В режиме preview используем специальную обработку
        if viewModel.isPreviewMode {
            viewModel.seekInPreviewMode(to: time)
        } else {
            viewModel.seek(to: time)
        }
    }

    private func handleStartDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard let duration = viewModel.currentVideoFile?.duration else { return }

        let percent = Double(value.location.x / geometry.size.width)
        let time = percent * duration
        viewModel.setStartTime(time)
    }

    private func handleEndDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard let duration = viewModel.currentVideoFile?.duration else { return }

        let percent = Double(value.location.x / geometry.size.width)
        let time = percent * duration
        viewModel.setEndTime(time)
    }
}
