/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Contains the logic that represents the bounded canvas space.
*/

import RealityKit
import SwiftUI
import os

/// The app state which controls the size and placement of the person's drawing canvas.
@Observable
class DrawingCanvasSettings {
    /// 允许在任何位置绘画
    func isInsideCanvas(_ point: SIMD3<Float>) -> Bool {
        return true
    }
}
