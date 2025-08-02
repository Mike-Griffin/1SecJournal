//
//  CameraRecorderOverlayView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 6/1/25.
//
import SwiftUI

struct CameraRecorderOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: NavigationRouter


    @State private var recordPressed = false
let recordButtonAction: () -> ()
    var body: some View {
        VStack {
            HStack {
                Button {
                    // should remove the dismiss
                    dismiss()
                    Task { @MainActor in
                        if !router.path.isEmpty {
                            router.path.removeLast()
                        }
                    }
                } label: {
                    Image(systemName: "x.circle")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .tint(.white)
                        .fontWeight(.semibold)
//                        .padding(.top, 2)
//                        .padding(.leading, 2)
                }
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
