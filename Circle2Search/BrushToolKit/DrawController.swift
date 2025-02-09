import ARKit
import SwiftUICore
import RealityKit
import RealityKitContent

@MainActor
class DrawingController {
    let rootEntity: Entity
    var document: DrawingDocument
    var brushState: BrushState
    private var inputProvider: AnchorEntityInputProvider
    
    init(rootEntity: Entity,circleManager:CircleManager) async {
        self.rootEntity = rootEntity
        
        let sparkleBrushSetting:SparkleBrushStyleProvider.Settings = SparkleBrushStyleProvider.Settings(particlesColor: Color.mint.toSIMD())
        // 设置画笔状态为 sparkle
        self.brushState = BrushState(preset: .sparkle(settings: sparkleBrushSetting))
        
        // 创建画布设置（可以根据需要调整）
        let canvas = DrawingCanvasSettings()
        
        // 初始化 DrawingDocument
        self.document = await DrawingDocument(
            rootEntity: rootEntity,
            brushState: brushState,
            canvas: canvas,
            circleManager:circleManager
        )
        
        // 初始化输入提供器
        self.inputProvider = await AnchorEntityInputProvider(
            rootEntity: rootEntity,
            document: document
        )
    }
    
    func updateColor(newColor:Color) {
        document.overrideParticlesColor(newColor: newColor)
    }
}
extension DrawingController {
    private func setupMaterials() async -> (solid: RealityKit.Material, sparkle: RealityKit.Material)? {
        guard let solidMaterial = try? await ShaderGraphMaterial(
            named: "/Root/SolidPresetBrushMaterial",
            from: "PresetBrushMaterial",
            in: realityKitContentBundle
        ),
        var sparkleMaterial = try? await ShaderGraphMaterial(
            named: "/Root/SparklePresetBrushMaterial",
            from: "PresetBrushMaterial",
            in: realityKitContentBundle
        ) else {
            return nil
        }
        
        // 配置 sparkle 材质
        sparkleMaterial.writesDepth = false
        try? sparkleMaterial.setParameter(name: "ParticleUVScale", value: .float(8))
        
        return (solidMaterial, sparkleMaterial)
    }
}
extension DrawingController {
    func configureSparkleSettings() {
        // 配置 sparkle 画笔参数
        brushState.sparkleStyleSettings = SparkleBrushStyleProvider.Settings(
            initialSpeed: 0.012,
            size: 0.0002,
            particlesColor: [1, 1, 1]  // 白色粒子
        )
    }
}
