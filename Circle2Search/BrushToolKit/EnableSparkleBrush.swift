//
//  EnableSparkleBrush.swift
//  Circle2Search
//
//  Created by LightningLion on 2025/2/9.
//

import SwiftUI
import RealityKit
import MixedRealityKit

struct EnableSparkleBrush: ViewModifier {
    var circleManager:CircleManager
    @Binding
    var drawingController: DrawingController?
    @Binding
    var contentPack:RealityViewContentPack?
    func body(content: Content) -> some View {
        content
            .onReady($contentPack, perform: { content in
                
                // 创建根实体
                let rootEntity = Entity()
                rootEntity.position = .zero
                content.add(rootEntity)
                
                // 注册系统和组件
                HandComponent.registerComponent()
                DrawingSystem.registerSystem()
                
                SparkleBrushSystem.registerSystem()
                SparkleBrushComponent.registerComponent()
                
                // 初始化控制器
                Task { @MainActor in
                    let controller = await DrawingController(rootEntity: rootEntity, circleManager: circleManager)
                    self.drawingController = controller
                }
                
            })
    }
}
