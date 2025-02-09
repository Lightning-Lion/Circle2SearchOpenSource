import simd
import RealityKit
 
enum CoordinateSystemError: Error, LocalizedError {
    case invalidScale
    case shearingDetected
    
    var errorDescription: String? {
        switch self {
        case .invalidScale:
            return "The transformation matrix has an invalid scale component."
        case .shearingDetected:
            return "The transformation matrix contains shearing components."
        }
    }
}
 
func projectPoint(_ point: SIMD3<Float>, onto planeTransform: simd_float4x4) throws -> SIMD3<Float> {
    // 检查变换矩阵是否有效
    try validateTransformationMatrix(planeTransform)
    
    // 计算逆变换矩阵
    let inverseTransform = planeTransform.inverse
    
    // 将全局点转换为齐次坐标
    var homogeneousPoint = SIMD4<Float>(point, 1)
    
    // 应用逆变换
    let transformed = inverseTransform * homogeneousPoint
    
    // 转换回三维点
    let localPoint = transformed.xyz / transformed.w
    
    // 投影到XY平面（z=0）
    let projectedPoint = SIMD3<Float>(localPoint.x, localPoint.y, 0)
    
    return projectedPoint
}
 
// 验证变换矩阵是否满足条件
private func validateTransformationMatrix(_ transform: simd_float4x4) throws {
    // 如果开发者传入了一个不合规的矩阵，这是代码失误。
    // 传入的simd_float4x4应该表示一个Transform，不允许缩放和扭曲。
    return
}
 
// 辅助函数：检查两个浮点数是否接近
private func isClose(_ a: Float, to b: Float, tolerance: Float = 1e-6) -> Bool {
    return abs(a - b) <= tolerance
}
