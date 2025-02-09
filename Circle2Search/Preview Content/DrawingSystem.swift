import RealityKit
import os

class DrawingSystem: System {
    private static let handQuery = EntityQuery(where: .has(HandComponent.self))
    
    required init(scene: RealityKit.Scene) { }
    
    func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.handQuery, updatingSystemWhen: .rendering) {
            guard let handComponent = entity.components[HandComponent.self] else { continue }
          
            // 获取手部数据并发送到文档
            let provider = handComponent.provider
            provider.document.receive(
                input: handComponent.currentData,
                chirality: handComponent.chirality
            )
        }
    }
}
