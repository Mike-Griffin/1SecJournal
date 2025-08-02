//
//  PillButtonView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 5/31/25.
//

import SwiftUI

struct PillButtonView: View {
    let text: String
    let backgroundColor: Color
    
    var body: some View {
        Text(text)
            .pillButtonStyle(backgroundColor: backgroundColor)
    }
}

#Preview {
    SaveButtonView()
}

extension View {
    func pillButtonStyle(backgroundColor: Color) -> some View {
        modifier(PillViewModifier(backgroundColor: backgroundColor))
    }
}

struct PillViewModifier: ViewModifier {
    let backgroundColor: Color

    func body(content: Content) -> some View {
        content
            .fontWeight(.semibold)
            .frame(width: 100)
            .padding(8)
            .background(backgroundColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}
