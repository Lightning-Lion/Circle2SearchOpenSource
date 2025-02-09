/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
App state to describe the current state of the brush.
*/
import SwiftUI
import RealityKit

enum BrushPreset: Equatable {
    case sparkle(settings: SparkleBrushStyleProvider.Settings)
}

enum BrushType: Hashable, Equatable, CaseIterable, Identifiable {
    case sparkle
    
    var id: Self { return self }
    
    var label: String {
        switch self {
        case .sparkle: return "Sparkle"
        }
    }
}

@Observable
class BrushState {
    /// Type of brush being used.
    var brushType: BrushType = .sparkle
    
    /// Style settings for the sparkle brush type.
    var sparkleStyleSettings = SparkleBrushStyleProvider.Settings()
    
    init() {}
    
    init(preset: BrushPreset) { apply(preset: preset) }
    
    var asPreset: BrushPreset {
        switch brushType {
        case .sparkle: .sparkle(settings: sparkleStyleSettings)
        }
    }
    
    func apply(preset: BrushPreset) {
        switch preset {
        case let .sparkle(settings):
            brushType = .sparkle
            sparkleStyleSettings = settings
        }
    }
}
