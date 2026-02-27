//
//  FileInfoSection.swift
//  video-trimmer
//
//  Created by Eugen on 25.02.2026.
//

import SwiftUI

struct FileInfoSection: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        HStack {
                if let video = viewModel.currentVideoFile {
                    HStack(spacing: 24) {
                        Label(video.formattedDuration, systemImage: "clock")
                        Label(video.formattedSize, systemImage: "externaldrive")
                        Label(video.resolution, systemImage: "rectangle.dashed")
                    }
                    Spacer()
                    Button("Сменить файл") {
                        Task {
                            await viewModel.changeFile()
                        }
                    }
                    .disabled(viewModel.isProcessing)
                }
            }
            .padding(.vertical, 4)
    }
}
