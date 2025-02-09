/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Holds information about the state of the drawing in a given instance of the app.
  Also handles receiving inputs from the input provider and using it to draw.
*/
    
import Collections
import RealityKit
import RealityKitContent
import SwiftUI
import os

public enum Chirality: Equatable {
    case left, right
}

/// Data about the current user input.
struct InputData {
    /// Location of the thumb tip `AnchorEntity`.
    var thumbTip: SIMD3<Float>
    
    /// Location of the index finger tip `AnchorEntity`.
    var indexFingerTip: SIMD3<Float>
    
    /// The location of the brush tip. This is where the person is drawing.
    var brushTip: SIMD3<Float> {
        return (thumbTip + indexFingerTip) / 2
    }
    
    /// True if the person is actively drawing.
    var isDrawing: Bool {
        return distance(thumbTip, indexFingerTip) < 0.015
    }
}

/// Stored state of the drawing.
class DrawingDocument {
    /// Current state of the drawing canvas.
    let canvas: DrawingCanvasSettings
    
    /// Root entity of the drawing.
    private let rootEntity: Entity
    
    /// Current settings of the brush.
    private let brushState: BrushState
    
    /// Drawing data from the left hand.
    private var leftSource: DrawingSource
    
    /// Drawing data from the right hand.
    private var rightSource: DrawingSource
    
    /// Time the drawing was initialized.
    private var startDate: Date
    
    private var overrideParticlesColor:Color
    
    @MainActor
    init(rootEntity: Entity, brushState: BrushState, canvas: DrawingCanvasSettings,circleManager:CircleManager) async {
        self.rootEntity = rootEntity
        self.brushState = brushState
        self.startDate = .now
        self.canvas = canvas
        
        let leftRootEntity = Entity()
        let rightRootEntity = Entity()
        rootEntity.addChild(leftRootEntity)
        rootEntity.addChild(rightRootEntity)
        
        var solidMaterial: RealityKit.Material = SimpleMaterial()
        if let material = try? await ShaderGraphMaterial(named: "/Root/Material",
                                                         from: "SolidBrushMaterial",
                                                         in: realityKitContentBundle) {
            solidMaterial = material
        }
        
        var sparkleMaterial: RealityKit.Material = SimpleMaterial()
        if var material = try? await ShaderGraphMaterial(named: "/Root/SparkleBrushMaterial",
                                                         from: "SparkleBrushMaterial",
                                                         in: realityKitContentBundle) {
            
            try? material.setParameter(name: "ParticleUVScale", value: .float(8))
            material.writesDepth = false
            sparkleMaterial = material
        }
        
        leftSource = await DrawingSource(rootEntity: leftRootEntity,
                                         solidMaterial: solidMaterial,
                                         sparkleMaterial: sparkleMaterial,
                                         circleManager:circleManager)
        rightSource = await DrawingSource(rootEntity: rightRootEntity,
                                          solidMaterial: solidMaterial,
                                          sparkleMaterial: sparkleMaterial,
                                          circleManager:circleManager)
        
        // 使用一开始设置的颜色
        self.overrideParticlesColor = brushState.sparkleStyleSettings.particlesColor.toColor()
    }
    
    @MainActor
    func receive(input: InputData?, chirality: Chirality) {
        var input = input
//        os_log("查到手部位置")
        if let input {
//            os_log("input.brushTip:\(input.brushTip),input.indexFingerTip:\(input.indexFingerTip.debugDescription),input.thumbTip:\(input.thumbTip.debugDescription),input.isDrawing:\(input.isDrawing)")
        }
        if let brushTip = input?.brushTip, !canvas.isInsideCanvas(brushTip) {
            input = .none
        }
        
        switch chirality {
        case .left:
//            leftSource.receive(input: input, time: startDate.distance(to: .now), state: brushState)
            // 我们只启用右手
            // 这样左手可以用来操控UI
            // 而不会因为意外捏和了左手而在空中留下不可见的微小小线段。
            break
        case .right:
            var brushStateModifiedParticlesColor = brushState
            brushStateModifiedParticlesColor.sparkleStyleSettings.particlesColor = overrideParticlesColor.toSIMD()
            rightSource.receive(input: input, time: startDate.distance(to: .now), state: brushStateModifiedParticlesColor)
        }
    }
    
    func overrideParticlesColor(newColor:Color) {
        self.overrideParticlesColor = newColor
    }
}
