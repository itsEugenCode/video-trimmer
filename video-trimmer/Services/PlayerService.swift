//
//  PlayerService.swift
//  video-trimmer
//
//  Created by Eugen on 26.02.2026.
//

import Foundation
import AVFoundation
import Combine

final class PlayerService: ObservableObject {
    // MARK: - Published свойства
    
    @Published var currentTime: TimeInterval = 0
    @Published var isPlaying: Bool = false
    @Published var duration: TimeInterval = 0
    @Published var player: AVPlayer?
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    // MARK: - Private свойства
    
    private var timeObserver: Any?
    private var playerItemObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    
    // MARK: - Инициализация
    
    init() {}
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public методы
    
    func load(url: URL) async {
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }
        
        cleanup()
        
        do {
            let asset = AVURLAsset(url: url)
            
            // Загружаем свойства через новый API
            let duration = try await asset.load(.duration)
            let tracks = try await asset.load(.tracks)
            
            let playerItem = AVPlayerItem(asset: asset)
            let newPlayer = AVPlayer(playerItem: playerItem)
            newPlayer.volume = 1.0
            newPlayer.actionAtItemEnd = .pause
            
            await MainActor.run {
                self.player = newPlayer
                self.duration = CMTimeGetSeconds(duration)
                self.setupObservers()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = "Ошибка загрузки видео: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func play() {
        guard let player = player else {
            print("❌ [PlayerService] play: player is nil")
            return
        }
        
        guard let item = player.currentItem else {
            print("❌ [PlayerService] play: currentItem is nil")
            return
        }
        
        print("🔵 [PlayerService] play: status = \(item.status.rawValue)")
        
        if item.status == .readyToPlay {
            print("▶️ [PlayerService] play: starting playback")
            player.play()
            isPlaying = true
        } else {
            print("⏳ [PlayerService] play: waiting for readyToPlay...")
            // Ждём готовности
            waitUntilReadyToPlay { [weak self] in
                Task { @MainActor in
                    self?.play()
                }
            }
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to time: TimeInterval) {
        guard let player = player else { return }

        let clampedTime = max(0, min(time, duration))
        let seekTime = CMTime(seconds: clampedTime, preferredTimescale: 600)

        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = clampedTime
            }
        }
    }
    
    func seek(to time: TimeInterval, completion: @escaping () -> Void) {
        guard let player = player else {
            completion()
            return
        }

        let clampedTime = max(0, min(time, duration))
        let seekTime = CMTime(seconds: clampedTime, preferredTimescale: 600)

        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = clampedTime
                completion()
            }
        }
    }
    
    func skip(by interval: TimeInterval) {
        let newTime = currentTime + interval
        seek(to: max(0, min(newTime, duration)))
    }
    
    // MARK: - Private методы
    
    private func setupObservers() {
        guard let player = player else { return }
        
        // Наблюдатель за окончанием воспроизведения
        playerItemObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
            }
        }
        
        // Наблюдатель за временем воспроизведения
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = CMTimeGetSeconds(time)
            }
        }
        
        // KVO наблюдатель за статусом элемента
        statusObserver = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                print("📊 [PlayerService] status changed to: \(item.status.rawValue)")
                if item.status == .readyToPlay {
                    print("✅ [PlayerService] player is ready to play")
                } else if item.status == .failed {
                    print("❌ [PlayerService] player failed: \(item.error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }
    
    private func waitUntilReadyToPlay(completion: @escaping () -> Void) {
        guard let item = player?.currentItem else {
            completion()
            return
        }
        
        if item.status == .readyToPlay {
            completion()
            return
        }
        
        var observer: NSKeyValueObservation?
        observer = item.observe(\.status, options: [.new]) { item, _ in
            if item.status == .readyToPlay || item.status == .failed {
                observer?.invalidate()
                completion()
            }
        }
        
        // Таймаут 5 секунд
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            observer?.invalidate()
            completion()
        }
    }
    
    func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        if let observer = playerItemObserver {
            NotificationCenter.default.removeObserver(observer)
            playerItemObserver = nil
        }
        
        statusObserver?.invalidate()
        statusObserver = nil
        
        player?.pause()
        player = nil
        currentTime = 0
        duration = 0
        isPlaying = false
        isLoading = false
    }
}
