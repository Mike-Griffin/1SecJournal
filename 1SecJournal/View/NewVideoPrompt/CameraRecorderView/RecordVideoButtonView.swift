//
//  RecordButtonView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 5/31/25.
//

import SwiftUI

/// Follows the recorder's real state, so the ring only runs while a recording is in progress
struct RecordVideoButtonView: View {
    let state: RecordingState
    let duration: TimeInterval
    var action: () -> Void
    @State private var countdownProgress = 0.0

    private var isActive: Bool { state != .idle }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isActive {
                    Circle()
                        .trim(from: 0, to: countdownProgress)
                        .stroke(Color.yellow, lineWidth: 8)
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 60, height: 60)
                }
                RoundedRectangle(cornerRadius: isActive ? 4 : 30)
                    .fill(.red)
                    .frame(width: isActive ? 40 : 50, height: isActive ? 40 : 50)
            }
            // The same size in every state (the ring plus its stroke), so the center never moves
            .frame(width: 108, height: 108)
            .animation(.easeInOut(duration: 0.3), value: isActive)
        }
        .onChange(of: state) { _, newState in
            switch newState {
            case .recording:
                countdownProgress = 0
                withAnimation(.linear(duration: duration)) {
                    countdownProgress = 1
                }
            case .idle:
                countdownProgress = 0
            case .starting, .finished:
                break
            }
        }
    }
}

#Preview {
    RecordVideoButtonView(state: .idle, duration: 1, action: { AppLogger.log("record tapped") })
}
