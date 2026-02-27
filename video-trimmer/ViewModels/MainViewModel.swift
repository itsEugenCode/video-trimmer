//
//  MainViewModel.swift
//  video-trimmer
//
//  Created by Eugen on 25.02.2026.
//

import Foundation
import AVFoundation
import AppKit
import Combine

@MainActor
class MainViewModel: ObservableObject {
    // MARK: - Published свойства
    
    @Published var currentVideoFile: VideoFile?
    @Published var trimSettings = TrimSettings()
    @Published var currentTime: TimeInterval = 0
    @Published var isPlaying: Bool = false
    @Published var isPreviewMode: Bool = false
    @Published var isLoading: Bool = false
    @Published var isProcessing: Bool = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?
    @Published var showProgressOverlay: Bool = false
    @Published var outputFileName: String = ""
    
    // MARK: - Сервисы
    
    let playerService = PlayerService()
    private let fileService = FileService()
    private let trimmer = VideoTrimmerEngine()
    private let namingService = FileNamingService()
    private let scanner = VideoScanner()
    private let validator = VideoValidator()
    
    // MARK: - Private свойства
    
    private var currentTask: Task<Void, Error>?
    private var localFileURL: URL?
    private var previewLoopObserver: Any?
    
    // MARK: - Вычисляемые свойства
    
    var player: AVPlayer? {
        playerService.player
    }
    
    var canStartTrimming: Bool {
        guard let videoFile = currentVideoFile else { return false }
        guard !isProcessing else { return false }
        return validator.validateTrimSettings(trimSettings, for: videoFile).isValid
    }
    
    var canPlay: Bool {
        currentVideoFile != nil && playerService.player != nil
    }
    
    var canSetStartTime: Bool {
        currentVideoFile != nil && !isProcessing
    }
    
    var canSetEndTime: Bool {
        currentVideoFile != nil && !isProcessing
    }
    
    var startTimeFormatted: String {
        trimSettings.startTime.formattedTime
    }
    
    var endTimeFormatted: String {
        trimSettings.endTime.formattedTime
    }
    
    var currentTimeFormatted: String {
        currentTime.formattedTime
    }
    
    var durationFormatted: String {
        currentVideoFile?.formattedDuration ?? "00:00"
    }
    
    // MARK: - Инициализация
    
    init() {
        setupPlayerServiceObservers()
    }
    
    // MARK: - Работа с файлами
    
    func loadVideo(from url: URL) async {
        currentTask?.cancel()
        
        currentTask = Task {
            await loadVideoInternal(from: url)
        }
    }
    
    private func loadVideoInternal(from url: URL) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let localURL = try await fileService.copyToAppContainer(url: url, subfolder: "Videos")
            localFileURL = localURL
            
            let videoFile = try await scanner.getVideoInfo(from: localURL)
            
            guard videoFile.isValid else {
                errorMessage = videoFile.errorMessage ?? "Невалидный видеофайл"
                isLoading = false
                return
            }
            
            currentVideoFile = videoFile
            trimSettings.setFullDuration(videoFile.duration)
            
            // Загружаем плеер
            await playerService.load(url: localURL)
            
            outputFileName = namingService.generateUniqueName(originalURL: localURL, in: localURL.deletingLastPathComponent()).lastPathComponent
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func selectFile() async {
        let supportedTypes = Constants.supportedFormats.map { UTType(filenameExtension: $0) ?? .movie }.compactMap { $0 }
        
        guard let url = await fileService.selectFile(allowedContentTypes: supportedTypes) else {
            return
        }
        
        await loadVideo(from: url)
    }
    
    func handleDrop(url: URL) async {
        guard url.isSupportedVideoFormat else {
            errorMessage = "Неподдерживаемый формат файла"
            return
        }
        
        await loadVideo(from: url)
    }
    
    func handleDropFromProviders(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            
            Task { @MainActor in
                await self?.handleDrop(url: url)
            }
        }
    }
    
    func changeFile() async {
        resetState()
        await selectFile()
    }
    
    // MARK: - Воспроизведение
    
    private var lastToggleTime: TimeInterval = 0
    
    func togglePlay() {
        let now = Date.timeIntervalSinceReferenceDate
        // Защита от дублирования (если вызван чаще чем 100мс — игнорируем)
        if now - lastToggleTime < 0.1 {
            print("⚠️ [MainViewModel] togglePlay пропущен (debounce)")
            return
        }
        lastToggleTime = now
        
        print("🔴 [MainViewModel] togglePlay() вызван")
        print("🔴 - currentVideoFile: \(currentVideoFile != nil ? "OK" : "nil")")
        print("🔴 - player: \(player != nil ? "OK" : "nil")")
        print("🔴 - isPlaying: \(isPlaying)")
        
        guard currentVideoFile != nil else {
            print("❌ [MainViewModel] togglePlay: нет видео")
            return
        }
        
        playerService.togglePlay()
        isPlaying = playerService.isPlaying
        
        if isPlaying && isPreviewMode {
            setupPreviewLoop()
        }
    }
    
    func seek(to time: TimeInterval) {
        playerService.seek(to: time)
        currentTime = time
    }
    
    func skipForward() {
        playerService.skip(by: Constants.skipDuration)
    }
    
    func skipBackward() {
        playerService.skip(by: -Constants.skipDuration)
    }
    
    // MARK: - Preview режим
    
    private func isInTrimRange(_ time: TimeInterval) -> Bool {
        return time >= trimSettings.startTime && time <= trimSettings.endTime
    }
    
    private func setupPreviewLoop() {
        // Сначала удаляем старый observer если есть
        if let observer = previewLoopObserver {
            playerService.player?.removeTimeObserver(observer)
            previewLoopObserver = nil
        }

        guard let player = playerService.player else { return }
        
        // Используем актуальные значения из trimSettings
        // + небольшой буфер чтобы плеер не зависал на границах
        let rewindBuffer: TimeInterval = 0.1
        
        previewLoopObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0/30.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }

                let seconds = CMTimeGetSeconds(time)
                let startTime = self.trimSettings.startTime
                let endTime = self.trimSettings.endTime

                // Если дошли до конца диапазона — перематываем на start + буфер
                if seconds >= endTime {
                    self.playerService.seek(to: startTime + rewindBuffer) {
                        self.playerService.play()
                    }
                }
                // Если вышли за начало — тоже перематываем
                else if seconds < startTime {
                    self.playerService.seek(to: startTime + rewindBuffer) {
                        self.playerService.play()
                    }
                }
            }
        }
    }
    
    func togglePreviewMode() {
        isPreviewMode.toggle()
        
        let rewindBuffer: TimeInterval = 0.1

        if isPreviewMode {
            // Вход в режим preview
            // Если текущее время вне диапазона — перематываем на start + буфер
            if !isInTrimRange(currentTime) {
                playerService.pause()
                playerService.seek(to: trimSettings.startTime + rewindBuffer) { [weak self] in
                    guard let self = self else { return }
                    self.setupPreviewLoop()
                    self.playerService.play()
                    self.isPlaying = true
                }
            } else {
                setupPreviewLoop()
                if !isPlaying {
                    playerService.play()
                    isPlaying = true
                }
            }
        } else {
            // Выход из режима preview — удаляем observer
            if let observer = previewLoopObserver {
                playerService.player?.removeTimeObserver(observer)
                previewLoopObserver = nil
            }
            // Продолжаем воспроизведение без зацикливания
        }
    }
    
    func seekInPreviewMode(to time: TimeInterval) {
        playerService.pause()

        let rewindBuffer: TimeInterval = 0.1
        let targetTime = isInTrimRange(time) ? time : trimSettings.startTime + rewindBuffer

        playerService.seek(to: targetTime) { [weak self] in
            guard let self = self else { return }
            self.playerService.play()
            self.isPlaying = true
            self.setupPreviewLoop()
        }
    }
    
    // MARK: - Установка времени обрезки
    
    func setStartTimeToCurrentTime() {
        guard let videoFile = currentVideoFile else { return }

        trimSettings.setStartTime(currentTime, maxDuration: videoFile.duration)
        objectWillChange.send()

        // Если в preview режиме — пересоздаём loop с новыми значениями
        if isPreviewMode {
            if currentTime < trimSettings.startTime {
                seek(to: trimSettings.startTime)
            }
            setupPreviewLoop()
        }
    }

    func setEndTimeToCurrentTime() {
        guard let videoFile = currentVideoFile else { return }

        trimSettings.setEndTime(currentTime, maxDuration: videoFile.duration)
        objectWillChange.send()

        // Если в preview режиме — пересоздаём loop с новыми значениями
        if isPreviewMode {
            if currentTime > trimSettings.endTime {
                seek(to: trimSettings.startTime)
            }
            setupPreviewLoop()
        }
    }
    
    func setStartTime(_ time: TimeInterval) {
        guard let videoFile = currentVideoFile else { return }
        trimSettings.setStartTime(time, maxDuration: videoFile.duration)
        objectWillChange.send()
    }
    
    func setEndTime(_ time: TimeInterval) {
        guard let videoFile = currentVideoFile else { return }
        trimSettings.setEndTime(time, maxDuration: videoFile.duration)
        objectWillChange.send()
    }
    
    func resetTrim() {
        guard let videoFile = currentVideoFile else { return }
        
        trimSettings.startTime = 0
        trimSettings.endTime = videoFile.duration
        
        seek(to: 0)
        objectWillChange.send()
    }
    
    // MARK: - Обрезка видео

    func startTrimming() async {
        guard let videoFile = currentVideoFile else { return }
        guard validator.validateTrimSettings(trimSettings, for: videoFile).isValid else { return }

        isProcessing = true
        progress = 0
        showProgressOverlay = true

        guard let localURL = localFileURL else {
            errorMessage = "Локальная копия видео не найдена"
            isProcessing = false
            showProgressOverlay = false
            return
        }

        // Генерируем имя файла в папке Downloads (App Sandbox разрешает запись туда)
        let downloadsFolder = fileService.downloadsFolder
        let outputURL = namingService.generateUniqueName(
            originalURL: localURL,
            in: downloadsFolder,
            preferredExtension: localURL.pathExtension
        )

        outputFileName = outputURL.lastPathComponent

        do {
            let result = try await trimmer.trim(
                videoFile: videoFile,
                settings: trimSettings,
                outputURL: outputURL
            )

            isProcessing = false
            showProgressOverlay = false
            
            if result.success, let outputURL = result.outputURL {
                NSWorkspace.shared.selectFile(outputURL.path, inFileViewerRootedAtPath: outputURL.deletingLastPathComponent().path)
            } else {
                errorMessage = result.errorMessage ?? "Неизвестная ошибка при обрезке"
            }
        } catch {
            isProcessing = false
            showProgressOverlay = false
            errorMessage = error.localizedDescription
        }
    }
    
    func cancelTrimming() {
        trimmer.cancel()
        isProcessing = false
        showProgressOverlay = false
    }
    
    // MARK: - Сброс состояния
    
    func resetState() {
        currentTask?.cancel()
        currentTask = nil
        
        currentVideoFile = nil
        localFileURL = nil
        trimSettings = TrimSettings()
        currentTime = 0
        isPlaying = false
        isPreviewMode = false
        isLoading = false
        isProcessing = false
        progress = 0
        errorMessage = nil
        outputFileName = ""
        
        playerService.cleanup()
        
        if let observer = previewLoopObserver {
            playerService.player?.removeTimeObserver(observer)
        }
        previewLoopObserver = nil
    }
    
    // MARK: - Timeline
    
    func seekToTimelinePosition(_ percent: CGFloat, bounds: ClosedRange<CGFloat>? = nil) {
        guard let videoFile = currentVideoFile else { return }
        
        var targetPercent = percent
        
        if isPreviewMode, let bounds = bounds {
            targetPercent = max(bounds.lowerBound, min(bounds.upperBound, percent))
        }
        
        let time = TimeInterval(targetPercent) * videoFile.duration
        seek(to: time)
    }
    
    // MARK: - Наблюдатели
    
    private func setupPlayerServiceObservers() {
        playerService.$currentTime
            .receive(on: RunLoop.main)
            .sink { [weak self] time in
                self?.currentTime = time
            }
            .store(in: &ObservationToken.tokens)
        
        playerService.$isPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] isPlaying in
                self?.isPlaying = isPlaying
            }
            .store(in: &ObservationToken.tokens)
    }
}

// MARK: - ObservationToken

private class ObservationToken {
    static var tokens: Set<AnyCancellable> = []
}
