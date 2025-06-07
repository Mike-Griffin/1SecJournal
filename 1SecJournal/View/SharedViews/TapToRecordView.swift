//
//  TapToRecordView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 6/2/25.
//

import SwiftUI

struct TapToRecordView: View {
    let text: String
    let height: CGFloat
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.2))
                .frame(height: height)
            
            VStack {
                Image(systemName: "video.fill.badge.plus")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                Text(text)
                    .foregroundColor(.primary)
                    .font(.headline)
            }
        }
    }
}
