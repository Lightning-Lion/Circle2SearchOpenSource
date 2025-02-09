/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Evaluates and stores information about strokes based on someone's inputs and style parameters.
*/

import Algorithms
import Collections
import Foundation
import RealityKit
import os

private extension Collection where Element: FloatingPoint {
    
    /// Computes the average over this collection, omitting a number of the largest and smallest values.
    ///
    /// - Parameter truncation: The number or largest and smallest values to omit.
    /// - Returns: The mean value of the collection, after the truncated values are omitted.
    func truncatedMean(truncation: Int) -> Element {
        guard !isEmpty else { return .zero }
        
        var sortedSelf = Deque(sorted())
        let truncationLimit = (count - 1) / 2
        sortedSelf.removeFirst(Swift.min(truncationLimit, truncation))
        sortedSelf.removeLast(Swift.min(truncationLimit, truncation))
        return sortedSelf.reduce(Element.zero) { $0 + $1 } / Element(sortedSelf.count)
    }
}

public struct DrawingSource {
    private let rootEntity: Entity
    private var sparkleMaterial: RealityKit.Material
    
    private var sparkleMeshGenerator: SparkleDrawingMeshGenerator
    
    private var inputsOverTime: Deque<(SIMD3<Float>, TimeInterval)> = []
    
    private var sparkleProvider = SparkleBrushStyleProvider()
    
    private var currentSparkleMeshEntity:Entity
    
    private var circleManager:CircleManager
    
    private var currentCircle:SpatialCircle? = nil
    
    private mutating func trace(position: SIMD3<Float>, speed: Float, state: BrushState) {
        os_log("进行了一次trace")
        switch state.brushType {
        case .sparkle:
            let styled = sparkleProvider.styleInput(position: position, speed: speed,
                                                    settings: state.sparkleStyleSettings)
            sparkleMeshGenerator.trace(point: styled)
        }
    }
    
    @MainActor
    init(rootEntity: Entity, solidMaterial: Material? = nil, sparkleMaterial: Material? = nil,circleManager:CircleManager) async {
        self.rootEntity = rootEntity
        
        let sparkleMeshEntity = Entity()
        rootEntity.addChild(sparkleMeshEntity)
        self.currentSparkleMeshEntity = sparkleMeshEntity
        // 初始透明度为1，完全不透明
        sparkleMeshEntity.components.set(OpacityComponent(opacity: 1))
        self.sparkleMaterial = sparkleMaterial ?? SimpleMaterial()
        sparkleMeshGenerator = SparkleDrawingMeshGenerator(rootEntity: sparkleMeshEntity,
                                                           material: self.sparkleMaterial)
        self.circleManager = circleManager
    }
    
    @MainActor
    mutating func receive(input: InputData?, time: TimeInterval, state: BrushState) {
//        os_log("走到了receive")
        while let (_, headTime) = inputsOverTime.first, time - headTime > 0.1 {
            inputsOverTime.removeFirst()
        }
        
        if let brushTip = input?.brushTip {
            let lastInputPosition = inputsOverTime.last?.0
            inputsOverTime.append((brushTip, time))
            
            if let lastInputPosition, lastInputPosition == brushTip {
                return
            }
        }
        
        let speedsOverTime = inputsOverTime.adjacentPairs().map { input0, input1 in
            let (point0, time0) = input0
            let (point1, time1) = input1
            let distance = distance(point0, point1)
            let time = abs(time0 - time1)
            return distance / Float(time)
        }
        
        let smoothSpeed = speedsOverTime.truncatedMean(truncation: 2)
        
        if let input, input.isDrawing {
            os_log("input.isDrawing")
            // 如果已有正在画的圆，就继续添加点，否则，创建一个新的圆，并添加点
            if let currentCircle {
                currentCircle.addPoint(point: input.brushTip)
            } else {
                let newCurrentCircle = circleManager.createNewCircle()
                self.currentCircle = newCurrentCircle
                newCurrentCircle.addPoint(point: input.brushTip)
            }
            trace(position: input.brushTip, speed: smoothSpeed, state: state)
        } else {
           
            if sparkleMeshGenerator.isDrawing {
                os_log("用户画完了一个圈")
                // 给正在画的圆结束
                if let currentCircle {
                    currentCircle.done()
                    self.currentCircle = nil
                } else {
                    os_log("不应该出现这种情况。设计为圆不能一上来就不isDrawing啊。")
                }
                sparkleMeshGenerator.endStroke()
                // 渐隐这个圈的粒子
                let currentSparkleMeshEntityRef = currentSparkleMeshEntity
                Task { @MainActor in
                    do {
                        var done = false
                        var startDate = Date.now
                        var animationDuration:TimeInterval = 0.3
                        while !done {
                            let isAnimationDone:Bool = DrawingSource.updateOpacity(currentSparkleMeshEntityRef: currentSparkleMeshEntityRef, startDate: startDate, animationDuration: animationDuration)
                            if isAnimationDone {
                                done = true
                            }
                            // 60 FPS的渐隐动画
                            try await Task.sleep(for: .seconds(1/60))
                        }
                        // 动画好了，移除实体，节约性能
                        currentSparkleMeshEntityRef.removeFromParent()
                        os_log("实体已移除")
                    } catch {
                        os_log("\(error.localizedDescription)")
                    }
                }
                // 使用下一个实体来显示下一个圈
                useNextEntity()
            }
        }
    }
    
    ///如果返回true，代表动画已完成
    static
    func updateOpacity(currentSparkleMeshEntityRef:Entity,startDate:Date,animationDuration:TimeInterval) -> Bool {
        
            guard let opacityComponent = currentSparkleMeshEntityRef.components[OpacityComponent.self] else {
                os_log("不应该没有OpacityComponent组件")
                return true
            }
            guard opacityComponent.opacity > 0 else {
                
                os_log("渐隐完成")
                return true
            }
            var progress = Float(Date.now.timeIntervalSince(startDate) / animationDuration)
            guard progress <= 1 else {
                os_log("渐隐动画时间到了")
                return true
            }
            // 如果 progress 是 0，opacity,1
            // 当 progress 到 1的时候，opacity是0
            func getOpacityByProgress(progress:Float) -> Float {
                return 1-progress
            }
            currentSparkleMeshEntityRef.components.set(OpacityComponent(opacity: getOpacityByProgress(progress: progress)))
        // 需要继续进行下一个动画帧
        return false
    }
    mutating func useNextEntity() {
        let sparkleMeshEntity = Entity()
        rootEntity.addChild(sparkleMeshEntity)
        self.currentSparkleMeshEntity = sparkleMeshEntity
        // 初始透明度为1，完全不透明
        sparkleMeshEntity.components.set(OpacityComponent(opacity: 1))
        self.sparkleMaterial = sparkleMaterial ?? SimpleMaterial()
        sparkleMeshGenerator = SparkleDrawingMeshGenerator(rootEntity: sparkleMeshEntity,
                                                           material: self.sparkleMaterial)
    }
}

