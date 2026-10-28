//
//  ToastView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 10/27/26.
//

import SwiftUI

struct ToastView: View {
    let message: String
    var systemImage: String = "exclamationmark.triangle.fill"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.yellow)
            Text(message)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ToastView(message: "Camera access is off. Enable it in Settings.")
        .padding()
        .background(.gray)
}
