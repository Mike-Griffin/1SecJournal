//
//  CreateStitchView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 6/7/25.
//
import SwiftUI
import SwiftData


struct CreateStitchView: View {
//    @Bindable var viewModel: CreateStitchViewModel
    
    @Bindable var viewModel: CreateStitchViewModel
    
//    init(videos: [DailyVideoEntry],
//         preselectedVideoId: UUID?,
//         modelContext: ModelContext) {
//        _viewModel = State(wrappedValue:
//                            CreateStitchViewModel(videos: videos,
//                                                  preselectedVideoId: preselectedVideoId,
//                                                  modelContext: modelContext))
//    }
    
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
                        AppLogger.log("Constructing stitch with \(viewModel.selectedIds.count) videos")
                        //dismiss()
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
            PeriodStitchSelectionView(viewModel: viewModel, groups: viewModel.monthGroups)
        case .year:
            PeriodStitchSelectionView(viewModel: viewModel, groups: viewModel.yearGroups)
        }
    }
}

struct PeriodStitchSelectionView: View {
    @Bindable var viewModel: CreateStitchViewModel
    let groups: [PeriodGroup]
    let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(groups) { group in
                PeriodCell(group: group, selection: viewModel.selection(of: group)) {
                    viewModel.togglePeriod(group)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

struct PeriodCell: View {
    let group: PeriodGroup
    let selection: PeriodSelection
    let onTap: () -> Void

    private var countText: String {
        group.videos.count == 1 ? "1 video" : "\(group.videos.count) videos"
    }

    private var selectionImageName: String {
        switch selection {
        case .none: return "circle"
        case .partial: return "minus.circle.fill"
        case .all: return "checkmark.circle.fill"
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // The stack only needs the cards that show
                ThumbnailStackView(images: group.videos.prefix(3).map(\.thumbnailImage))
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: selectionImageName)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.white, selection == .none ? .clear : .blue)
                            .shadow(radius: 2)
                            // Inside the top card, clear of the fanned cards
                            .padding(.top, 18)
                            .padding(.trailing, 22)
                    }
                Text(group.period.title)
                    .font(.headline)
                Text(countText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(group.period.title), \(countText)")
        .accessibilityValue(selection == .partial ? "Partly selected" : "")
        .accessibilityAddTraits(selection == .all ? [.isButton, .isSelected] : .isButton)
    }
}

struct CustomStitchSelectionView: View {
    @Bindable var viewModel: CreateStitchViewModel
    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(viewModel.videos) { video in
                VStack(spacing: 0) {
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
                    AppLogger.log("Tapped \(video.id) and ViewModel selectedIds is \(viewModel.selectedIds)")
                    // Should be within the viewModel
//                    if viewModel.selectedIds.contains(video.id) {
//                        viewModel.selectedIds.remove(video.id)
//                    } else {
//                        viewModel.selectedIds.insert(video.id)
//                        AppLogger.log("Interted \(video.id) so now viewModel.selectedIds is \(viewModel.selectedIds)")
//                    }
                    viewModel.selectVideo(video)
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    //CreateStitchView(viewModel: CreateStitchViewModel(videos: []) {_ in })
//    CreateStitchView( videos: [], {_ in })

}
