//
//  DrawLineError.swift
//  Circle2Search
//
//  Created by LightningLion on 2025/1/29.
//


import CoreGraphics
import UIKit

enum DrawLineError: LocalizedError {
    case invalidImage
    case contextCreationFailed
    case insufficientPoints
    case pointOutOfBounds(point: CGPoint)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "输入的图像无效"
        case .contextCreationFailed:
            return "创建图形上下文失败"
        case .insufficientPoints:
            return "需要至少两个点才能绘制线条"
        case .pointOutOfBounds(let point):
            return "点坐标超出范围：(\(point.x), \(point.y))，坐标范围应该在(0,0)到(1,1)之间"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .invalidImage:
            return "提供的图像可能已损坏或格式不正确"
        case .contextCreationFailed:
            return "系统内存不足或图像参数无效"
        case .insufficientPoints:
            return "点的数量少于2个，无法形成线条"
        case .pointOutOfBounds:
            return "坐标值必须在0到1之间（包含0和1）"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidImage:
            return "请检查输入图像是否有效，确保其未被损坏"
        case .contextCreationFailed:
            return "请尝试减小图像尺寸或释放系统内存"
        case .insufficientPoints:
            return "请确保提供至少两个点的坐标"
        case .pointOutOfBounds:
            return "请使用归一化坐标：左上角是(0,0)，右下角是(1,1)"
        }
    }
}

/// 在图像上绘制连线，允许点在画布外
/// - Parameters:
///   - image: 原始图像
///   - points: 点的数组，坐标系统：左上角是(0,0)，右下角是(1,1)
///   - lineWidth: 线条宽度
///   - lineColor: 线条颜色
///   - shadowColor: 阴影颜色
///   - shadowOffset: 阴影偏移
///   - shadowBlur: 阴影模糊度
/// - Returns: 绘制完成的新图像
/// - Throws: DrawLineError 类型的错误
func drawLinesBetweenPoints(
    on image: CGImage?,
    points: [CGPoint],
    lineWidth: CGFloat = 2.0,
    lineColor: UIColor = .red,
    shadowColor: UIColor = .black,
    shadowOffset: CGSize = CGSize(width: 2, height: 2),
    shadowBlur: CGFloat = 3.0
) throws -> CGImage {
    // 验证输入图像
    guard let image = image else {
        throw DrawLineError.invalidImage
    }
    
    // 验证点的数量
    guard points.count >= 2 else {
        throw DrawLineError.insufficientPoints
    }
    
    // 创建绘图上下文
    let width = image.width
    let height = image.height
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw DrawLineError.contextCreationFailed
    }
    
    // 绘制原始图像
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    
    // 设置线条属性
    context.setLineWidth(lineWidth)
    context.setStrokeColor(lineColor.cgColor)
    
    // 设置阴影
    context.setShadow(
        offset: shadowOffset,
        blur: shadowBlur,
        color: shadowColor.cgColor
    )
    
    // 转换坐标系统
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    
    // 开始绘制路径
    context.beginPath()
    
    // 转换第一个点的坐标并移动到该点
    let startPoint = CGPoint(
        x: points[0].x * CGFloat(width),
        y: points[0].y * CGFloat(height)
    )
    context.move(to: startPoint)
    
    // 连接所有点
    for point in points.dropFirst() {
        let cgPoint = CGPoint(
            x: point.x * CGFloat(width),
            y: point.y * CGFloat(height)
        )
        context.addLine(to: cgPoint)
    }
    
    // 绘制线条
    context.strokePath()
    
    // 生成新的图像
    guard let resultImage = context.makeImage() else {
        throw DrawLineError.contextCreationFailed
    }
    
    return resultImage
}

// 使用示例：
/*
// 在图像上绘制对角线
let points = [
    CGPoint(x: 0, y: 0),     // 左上角
    CGPoint(x: 0.5, y: 0.5), // 中心点
    CGPoint(x: 1, y: 1)      // 右下角
]

do {
    let resultImage = try drawLinesBetweenPoints(
        on: originalImage,
        points: points,
        lineWidth: 3.0,
        lineColor: .red,
        shadowColor: UIColor.black.withAlphaComponent(0.5)
    )
    let finalImage = UIImage(cgImage: resultImage)
    // 使用最终图像...
} catch let error as DrawLineError {
    print("绘制失败：\(error.localizedDescription)")
    print("失败原因：\(error.failureReason ?? "")")
    print("建议解决方案：\(error.recoverySuggestion ?? "")")
} catch {
    print("发生未知错误：\(error)")
}
*/
