//
//  RecordButtonView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 5/31/25.
//

import SwiftUI

struct RecordVideoButtonView: View {
    var action: () -> Void
    @State private var recording = false
    @State private var countdownProgress = 0.0


    var body: some View {
        Button {
            action()
            withAnimation(.easeInOut(duration: 0.3)) {
                recording.toggle()
            }
            countdownProgress = 0.0
            withAnimation(.linear(duration: 1.0)) {
                countdownProgress = 1.0
            }
        }  label: {
            let size = 60.0
            ZStack {
                if recording {
                    Circle()
                        .trim(from: 0, to: countdownProgress)
                        .stroke(Color.yellow, lineWidth: 8)
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                }
                if !recording {
                    Circle()
                        .fill(.white)
                        .frame(width: size, height: size)
                }
                RoundedRectangle(cornerRadius: recording ? 4 : 30)
                    .fill(.red)
                    .frame(width: recording ? 40 : 50, height: recording ? 40 : 50)

            }
        }
//        .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height - 200)
    }
    
    @ViewBuilder
    var recordButton: some View {
        let size = 60.0
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: size, height: size)
            Circle()
                .fill(.red)
                .frame(width: size - 10, height: size - 10)

        }
        
    }
    
    @ViewBuilder
    var stopButton: some View {
        let size = 60.0
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: size, height: size)
            Rectangle()
                .fill(.red)
                .frame(width: 25, height: 25)
        }
    }
}

#Preview {
    RecordVideoButtonView(action: { print("record tapped")})
}
