//
//  Circle2SearchApp.swift
//  Circle2Search
//
//  Created by LightningLion on 2025/1/28.
//

import SwiftUI

@main
struct Circle2SearchApp: App {

    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
        .windowResizability(.contentSize)
        
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView(circleManager: appModel.circleManager)
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
     }
}
