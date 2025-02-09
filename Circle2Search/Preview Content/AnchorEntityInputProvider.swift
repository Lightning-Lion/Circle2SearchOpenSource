import SwiftUI
import RealityKit

@Observable
class AnchorEntityInputProvider {
    private let rootEntity: Entity
    let document: DrawingDocument
    private var session: SpatialTrackingSession
    
    private let leftEntity = Entity()
    private let rightEntity = Entity()
    
    @MainActor
    init(rootEntity: Entity, document: DrawingDocument) async {
        self.rootEntity = rootEntity
        self.document = document
        
        // 初始化手部追踪会话
        session = SpatialTrackingSession()
        let configuration = SpatialTrackingSession.Configuration(tracking: [.hand])
        _ = await session.run(configuration)
        
        // 注册必要的组件和系统
        HandComponent.registerComponent()
        DrawingSystem.registerSystem()
        
        // 设置手部锚点
        setupHandAnchors()
    }
    
    private func setupHandAnchors() {
        // 左手锚点
        let leftIndexFinger = AnchorEntity(.hand(.left, location: .indexFingerTip))
        let leftThumb = AnchorEntity(.hand(.left, location: .thumbTip))
        
        // 右手锚点
        let rightIndexFinger = AnchorEntity(.hand(.right, location: .indexFingerTip))
        let rightThumb = AnchorEntity(.hand(.right, location: .thumbTip))
        
        // 设置左手
        leftEntity.components.set(HandComponent(
            chirality: .left,
            provider: self,
            thumbTip: leftThumb,
            indexFingerTip: leftIndexFinger
        ))
        
        // 设置右手
        rightEntity.components.set(HandComponent(
            chirality: .right,
            provider: self,
            thumbTip: rightThumb,
            indexFingerTip: rightIndexFinger
        ))
        
        // 添加到场景
        rootEntity.addChild(leftIndexFinger)
        rootEntity.addChild(leftThumb)
        rootEntity.addChild(leftEntity)
        
        rootEntity.addChild(rightIndexFinger)
        rootEntity.addChild(rightThumb)
        rootEntity.addChild(rightEntity)
    }
}
