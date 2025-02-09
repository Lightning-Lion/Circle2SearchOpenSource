import RealityKit
import simd

enum PanelError: Error, LocalizedError {
    case colinearPoints
    case parallelVectors
    case degenerateCase
    
    var errorDescription: String? {
        switch self {
        case .colinearPoints:
            return "The given points are colinear and cannot form a plane."
        case .parallelVectors:
            return "The plane's normal is parallel to the device's Y axis, making it impossible to find a perpendicular X axis."
        case .degenerateCase:
            return "Device is exactly on the plane surface."
        }
    }
}

class OrientedPanelTransformer {
    func computeCenter(of points: [SIMD3<Float>]) -> SIMD3<Float>? {
        guard !points.isEmpty else { return nil }
        
        let sums = points.reduce((0.0, 0.0, 0.0)) {
            (sums, point) in
            (sums.0 + Double(point.x), sums.1 + Double(point.y), sums.2 + Double(point.z))
        }
        
        let count = Double(points.count)
        let avgX = Float(sums.0 / count)
        let avgY = Float(sums.1 / count)
        let avgZ = Float(sums.2 / count)
        
        return SIMD3<Float>(x: avgX, y: avgY, z: avgZ)
    }
    func reparameterizeCurve(_ points: [SIMD3<Float>], toCount m: Int) -> [SIMD3<Float>] {
        guard !points.isEmpty else { return [] }
        guard m > 0 else { return [] }
        
        let n = points.count
        if n == 1 {
            return Array(repeating: points[0], count: m)
        }
        
        // Step 1: Compute deltas between consecutive points
        var deltas = [Float]()
        for i in 1..<n {
            let dx = points[i].x - points[i-1].x
            let dy = points[i].y - points[i-1].y
            let dz = points[i].z - points[i-1].z
            let distance = sqrt(dx*dx + dy*dy + dz*dz)
            deltas.append(distance)
        }
        
        // Step 2: Compute cumulative distances
        var cumulativeDistances = [Float]()
        cumulativeDistances.append(0)
        for delta in deltas {
            cumulativeDistances.append(cumulativeDistances.last! + delta)
        }
        
        let totalLength = cumulativeDistances.last!
        if totalLength == 0 {
            return Array(repeating: points[0], count: m)
        }
        
        // Step 3: Compute target interval
        let d = totalLength / Float(m - 1)
        
        // Step 4: Generate new points
        var result = [SIMD3<Float>]()
        for i in 0..<m {
            let s = Float(i) * d
            
            // Binary search to find the correct segment
            var low = 0
            var high = cumulativeDistances.count - 1
            var idx = 0
            while low <= high {
                let mid = (low + high) / 2
                if cumulativeDistances[mid] >= s {
                    idx = mid
                    high = mid - 1
                } else {
                    low = mid + 1
                }
            }
            
            if idx == 0 {
                result.append(points[0])
                continue
            }
            
            let prevDist = cumulativeDistances[idx-1]
            let currentDist = cumulativeDistances[idx]
            let t = (s - prevDist) / (currentDist - prevDist)
            
            let prevPoint = points[idx-1]
            let currentPoint = points[idx]
            
            let newX = prevPoint.x + t * (currentPoint.x - prevPoint.x)
            let newY = prevPoint.y + t * (currentPoint.y - prevPoint.y)
            let newZ = prevPoint.z + t * (currentPoint.z - prevPoint.z)
            
            result.append(SIMD3<Float>(newX, newY, newZ))
        }
        
        return result
    }
    func findPanelTransform(
        points: [SIMD3<Float>],
        center: SIMD3<Float>,
        deviceTransform: simd_float4x4
    ) throws -> simd_float4x4 {
        guard points.count == 3 else {
            fatalError("Exactly three points are required")
        }
        
        let a = points[0]
        let b = points[1]
        let c = points[2]
        
        // 计算平面法线基础向量
        let ab = b - a
        let ac = c - a
        let crossProduct = simd_cross(ab, ac)
        guard simd_length(crossProduct) > 1e-6 else {
            throw PanelError.colinearPoints
        }
        
        // 获取设备位置
        let devicePosition = deviceTransform.columns.3.xyz
        
        // 计算平面中心
        let center = center
        
        // 计算朝向向量
        let toDeviceVector = devicePosition - center
        guard simd_length(toDeviceVector) > 1e-6 else {
            throw PanelError.degenerateCase
        }
        
        // 确定法线方向
        var normal = simd_normalize(crossProduct)
        let dotValue = simd_dot(normal, simd_normalize(toDeviceVector))
        
        // 当法线背对设备时翻转方向
        if dotValue < 0 {
            normal = -normal
        }
        
        // 获取设备坐标系的Y轴方向
        let deviceYAxis = simd_normalize(deviceTransform.columns.1.xyz)
        
        // 重新计算X轴（确保与设备Y轴垂直）
        let xAxisUnnormalized = simd_cross(normal, deviceYAxis)
        guard simd_length(xAxisUnnormalized) > 1e-6 else {
            throw PanelError.parallelVectors
        }
        
        // 原始坐标系构建
         let originalX = simd_normalize(xAxisUnnormalized)
         let originalY = simd_normalize(simd_cross(normal, originalX))
         
         // 应用Z轴180度旋转
         let rotatedX = -originalX  // X轴反向
         let rotatedY = -originalY  // Y轴反向
         let rotatedZ = normal      // Z轴保持不变
         
         // 构建变换矩阵
         var transform = matrix_identity_float4x4
         transform.columns.0 = SIMD4(rotatedX, 0)  // 旋转后的X轴
         transform.columns.1 = SIMD4(rotatedY, 0)  // 旋转后的Y轴
         transform.columns.2 = SIMD4(rotatedZ, 0)  // 保持原Z轴方向
         transform.columns.3 = SIMD4(center, 1)    // 中心点不变
         
         return transform
    }
}


 
struct PointCloudProcessor {
    enum PointCloudError: Error, LocalizedError {
        case insufficientPoints
        case cannotSplitEqually
        
        var errorDescription: String? {
            switch self {
            case .insufficientPoints:
                return "Not enough points to process. At least 3 points are required."
            case .cannotSplitEqually:
                return "Cannot split the points equally into three parts with a maximum difference of one point."
            }
        }
    }
    
    static func processPoints(_ points: [SIMD3<Float>]) throws -> (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) {
        guard points.count >= 3 else {
            throw PointCloudError.insufficientPoints
        }
        
        let totalPoints = points.count
        let basePartSize = totalPoints / 3
        let remainder = totalPoints % 3
        
        // 根据余数分配额外的点
        let part1Size: Int
        let part2Size: Int
        let part3Size: Int
        
        switch remainder {
        case 0:
            part1Size = basePartSize
            part2Size = basePartSize
            part3Size = basePartSize
        case 1:
            part1Size = basePartSize + 1
            part2Size = basePartSize
            part3Size = basePartSize
        case 2:
            part1Size = basePartSize + 1
            part2Size = basePartSize + 1
            part3Size = basePartSize
        default:
            throw PointCloudError.cannotSplitEqually
        }
        
        guard part1Size > 0 && part2Size > 0 && part3Size > 0 else {
            throw PointCloudError.cannotSplitEqually
        }
        
        // 分割点集
        let part1 = Array(points[0..<part1Size])
        let part2StartIndex = part1Size
        let part2EndIndex = part2StartIndex + part2Size
        let part2 = Array(points[part2StartIndex..<part2EndIndex])
        let part3StartIndex = part2EndIndex
        let part3 = Array(points[part3StartIndex..<totalPoints])
        
        func average(of points: [SIMD3<Float>]) -> SIMD3<Float> {
            let sum = points.reduce(SIMD3<Float>.zero) { $0 + $1 }
            return sum / Float(points.count)
        }
        
        let avg1 = average(of: part1)
        let avg2 = average(of: part2)
        let avg3 = average(of: part3)
        
        return (avg1, avg2, avg3)
    }
}
 
// 使用示例：
//let points: [SIMD3<Float>] = /* 初始化你的点数组 */
//do {
//    let (avg1, avg2, avg3) = try PointCloudProcessor.processPoints(points)
//    print("Average points: \(avg1), \(avg2), \(avg3)")
//} catch PointCloudProcessor.PointCloudError.insufficientPoints {
//    print("Error: Not enough points.")
//} catch PointCloudProcessor.PointCloudError.cannotSplitEqually {
//    print("Error: Cannot split points equally with a maximum difference of one point.")
//} catch {
//    print("Unexpected error: \(error)")
//}
