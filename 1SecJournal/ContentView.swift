//
//  ContentView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/16/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HomeListView(viewModel: HomeListViewModel(modelContext))
    }
}

#Preview {
    ContentView()
}
