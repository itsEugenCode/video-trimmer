//
//  VideoPlayerView.swift
//  video-trimmer
//
//  Created by Eugen on 25.02.2026.
//

import AppKit
import AVKit
import SwiftUI

struct VideoPlayerView: NSViewRepresentable {
    @ObservedObject var viewModel: MainViewModel
    
    func makeNSView(context: Context) -> PlayerNSView {
        let playerView = PlayerNSView()
        playerView.player = viewModel.playerService.player
        return playerView
    }
    
    func updateNSView(_ nsView: PlayerNSView, context: Context) {
        nsView.player = viewModel.playerService.player
    }
}

class PlayerNSView: NSView {
    
    private var playerLayer: AVPlayerLayer?
    private var statusObserver: NSKeyValueObservation?
    
    private static var playerItemStatusContext = 0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    deinit {
        print("🧹 [PlayerNSView] deinit")
        statusObserver?.invalidate()
    }
    
    private func setupLayer() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
    }
    
    var player: AVPlayer? {
        get { playerLayer?.player }
        set {
            statusObserver?.invalidate()
            statusObserver = nil
            
            if let newPlayer = newValue {
                if playerLayer == nil {
                    playerLayer = AVPlayerLayer(player: newPlayer)
                    playerLayer?.videoGravity = .resizeAspect
                    playerLayer?.frame = bounds
                    playerLayer?.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
                    layer?.addSublayer(playerLayer!)
                } else {
                    playerLayer?.player = newPlayer
                }
                
                // Наблюдаем за статусом
                if let item = newPlayer.currentItem {
                    statusObserver = item.observe(\.status, options: [.new]) { item, _ in
                        print("📊 [PlayerNSView] status: \(item.status.rawValue)")
                        if item.status == .readyToPlay {
                            print("✅ [PlayerNSView] готов к воспроизведению")
                        } else if item.status == .failed {
                            print("❌ [PlayerNSView] ошибка: \(item.error?.localizedDescription ?? "unknown")")
                        }
                    }
                }
            } else {
                playerLayer?.player = nil
            }
        }
    }
    
    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
    }
}
