//
//  CameraRecorderOverlayView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 6/1/25.
//
import SwiftUI

struct CameraRecorderOverlayView: View {
    @State private var recordPressed = false
let recordButtonAction: () -> ()
    var body: some View {
        VStack {
            HStack {
                // CameraRecorderViewController draws the close button here so it's
                // available before the camera starts; this keeps the title centered
                Color.clear
                    .frame(width: 24, height: 24)
                Spacer()
                if !recordPressed {
                    Text("Record your 1 second memory")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
//                        .padding(.top, 2)
                }
                Spacer()
                
                Color.clear
                    .frame(width: 24, height: 24)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 40)
            .padding(.leading, 4)
            .padding(.top, 2)
            
            Spacer()
            RecordVideoButtonView(action: {
                withAnimation {
                    recordPressed = true
                }
                recordButtonAction()
            })
                .padding(.bottom)
        }
    }
}
