//
//  AdditionalActionsRow.swift
//  video-trimmer
//
//  Created by Eugen on 25.02.2026.
//

import SwiftUI

struct AdditionalActionsRow: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        HStack {
                Spacer()

                // Preview Trim
                Button(action: {
                    viewModel.togglePreviewMode()
                }) {
                    Label("Preview Trim", systemImage: "eye.fill")
                }
                .disabled(viewModel.currentVideoFile == nil)
                .foregroundColor(viewModel.isPreviewMode ? .accentColor : .primary)
                .help("Режим предварительного просмотра обрезки")

                // Reset
                Button(action: {
                    viewModel.resetTrim()
                }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .disabled(viewModel.currentVideoFile == nil)
                .help("Сбросить настройки обрезки")

                Spacer()
            }
            .padding(.vertical, 4)
    }
}
