//
//  MainView.swift
//  video-trimmer
//
//  Created by Eugen on 25.02.2026.
//

import SwiftUI
import AVKit
import AppKit

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                headerView
                    .padding([.top, .horizontal])
                
                Divider()
                
                if viewModel.currentVideoFile == nil {
                    InitialView(viewModel: viewModel)
                } else {
                    VStack(spacing: 12) {
                        FileInfoSection(viewModel: viewModel)
                        
                        if viewModel.playerService.isLoading {
                            Color.black
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .overlay(
                                    VStack(spacing: 16) {
                                        ProgressView()
                                            .scaleEffect(1.5)
                                        Text("Загрузка видео...")
                                            .foregroundColor(.white)
                                    }
                                )
                        } else if viewModel.player != nil {
                            VideoPlayerView(viewModel: viewModel)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Color.black
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .overlay(
                                    Text("Ошибка загрузки")
                                        .foregroundColor(.white)
                                )
                        }
                        
                        TimelineView(viewModel: viewModel)
                        ControlRow(viewModel: viewModel)
                        AdditionalActionsRow(viewModel: viewModel)
                        TrimActionSection(viewModel: viewModel)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 1000, minHeight: 700)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            viewModel.handleDropFromProviders(providers)
            return true
        }
        .onReceive(NotificationCenter.default.publisher(for: .togglePlay)) { _ in
            print("🔔 [MainView] togglePlay notification")
            viewModel.togglePlay()
        }
        .onReceive(NotificationCenter.default.publisher(for: .skipBack)) { _ in
            viewModel.skipBackward()
        }
        .onReceive(NotificationCenter.default.publisher(for: .skipForward)) { _ in
            viewModel.skipForward()
        }
        .onReceive(NotificationCenter.default.publisher(for: .setStart)) { _ in
            viewModel.setStartTimeToCurrentTime()
        }
        .onReceive(NotificationCenter.default.publisher(for: .setEnd)) { _ in
            viewModel.setEndTimeToCurrentTime()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFile)) { _ in
            Task {
                await viewModel.selectFile()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .trimVideo)) { _ in
            Task {
                await viewModel.startTrimming()
            }
        }
        .sheet(isPresented: $viewModel.showProgressOverlay) {
            ProgressOverlayView(viewModel: viewModel)
        }
        .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Video Trimmer")
                    .font(.title2.bold())
                Text("Обрезка видео")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

#Preview {
    MainView()
}
