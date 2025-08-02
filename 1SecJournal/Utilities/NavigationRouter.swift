//
//  NavigationRouter.swift
//  1SecJournal
//
//  Created by Mike Griffin on 8/2/25.
//
import SwiftUI

@MainActor
final class NavigationRouter: ObservableObject {
    enum Destination: Hashable {
        case home
        case videoRecorder
        case createStitch(videos: [DailyVideoEntry], preselectedId: UUID? = nil)
    }

//    @Published var path = NavigationPath()
    
    @Published var navigationStack: [Destination] = []
    
    func push(_ destination: Destination) {
        if let lastElement = navigationStack.last {
            guard lastElement != destination else {
                AppLogger.log("Attempting to push destination when it's already the last destination in the stack", level: .warning)
               return
           }
        }
         
//        path.append(destination)
        navigationStack.append(destination)
    }
    
    func removeLast() {
//        path.removeLast()
        guard !navigationStack.isEmpty else {
            return
        }
        navigationStack.removeLast()
    }
}
