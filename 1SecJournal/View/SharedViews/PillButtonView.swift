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
            .fontWeight(.semibold)
            .frame(width: 100)
            .padding(8)
            .background(backgroundColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}

#Preview {
    SaveButtonView()
}
