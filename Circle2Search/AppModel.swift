//
//  AppModel.swift
//  Circle2Search
//
//  Created by LightningLion on 2025/1/28.
//

import SwiftUI
import os

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    var circleManager = CircleManager()
}
