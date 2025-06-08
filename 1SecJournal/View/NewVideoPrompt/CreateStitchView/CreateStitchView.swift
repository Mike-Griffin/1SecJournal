//
//  CreateStitchView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 6/7/25.
//
import SwiftUI


struct CreateStitchView: View {
    @Bindable var viewModel: CreateStitchViewModel
    @Environment(\.dismiss) var dismiss
    var body: some View {
        ZStack {
            VStack {
                Text("Create Stitch")
                    .font(.title)
                Text("Select videos to combine into one video")
                    .font(.subheadline)
                Picker("Select Timeframe", selection: $viewModel.selectedTimeFrame) {
                    ForEach (StitchTimeframe.allCases, id: \.self) { timeframe in
                        Text(timeframe.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                ScrollView {
                    CreateStitchPickerView(viewModel: viewModel)
                }

                Spacer()
            }
            VStack {
                Spacer()
                if(!viewModel.selectedIds.isEmpty) {
                    Button {
                        print("save with \(viewModel.selectedIds.count) videos")
                        dismiss()
                        viewModel.createStitch()
                    } label: {
                        Text("Create stitch")
                            .fontWeight(.semibold)
//                            .frame(width: 100)
                            .padding(8)
                            .background(.gray)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, 8)
                    
                }
            }
        }
    }
}

struct CreateStitchPickerView : View {
    @Bindable var viewModel: CreateStitchViewModel
    
    var body: some View {
        switch viewModel.selectedTimeFrame {
        case .custom:
            CustomStitchSelectionView(viewModel: viewModel)
        case .month:
            Text("month")
        case .year:
            Text("year")
        }
    }
}

struct CustomStitchSelectionView: View {
    @Bindable var viewModel: CreateStitchViewModel
    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(viewModel.videos) { video in
                VStack {
                    ZStack {

                        Image(uiImage: video.thumbnailImage!)
                            .resizable()
                            .aspectRatio(9/16, contentMode: .fill)
                            .frame(width: (UIScreen.main.bounds.width - 8 * 4) / 3,  // 3 items, 4 gaps (3 between + 1 padding on edges)
                                   height: ((UIScreen.main.bounds.width - 8 * 4) / 3) * 16 / 9)
                            .clipped()
                            .cornerRadius(8)
                        VStack(alignment: .trailing) {
                            Image(systemName: viewModel.selectedIds.contains(video.id) ? "checkmark.circle.fill" : "circle")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding(.trailing, 8)
                                .padding(.top, 8)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    Text(video.date.videoFormattedDisplay)
                }
                .onTapGesture {
                    if viewModel.selectedIds.contains(video.id) {
                        viewModel.selectedIds.remove(video.id)
                    } else {
                        viewModel.selectedIds.insert(video.id)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    CreateStitchView(viewModel: CreateStitchViewModel(videos: []) {_ in })
}
