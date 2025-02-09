//
//  ChangeColorOvertime.swift
//  Circle2Search
//
//  Created by LightningLion on 2025/2/2.
//

import SwiftUI
import os

// 随着时间流逝，切换颜色
struct ChangeColorOvertime: ViewModifier {
    @Binding
    var mod:DrawingController?
    @State
    private var startDate = Date.now
    // 30帧更新颜色
    @State
    private var timer = Timer.publish(every: 1/30, on: .main, in: .default).autoconnect()
    func body(content: Content) -> some View {
        content
            .onReceive(timer, perform: { _ in
                guard let mod else {
                    return
                }
                do {
                    let currentDate:TimeInterval = Date.now.timeIntervalSince(startDate)
                    let duration:Double = getDuration(time: currentDate)
                    let currentColor = try Color.rainbow(from: duration)
                    mod.updateColor(newColor: currentColor)
                } catch {
                    os_log("\(error.localizedDescription)")
                }
            })
    }
    
    // 每2.2秒一个彩虹
    // 返回当前彩虹的值（0-1之间）
    func getDuration(time: TimeInterval) -> Double {
        let period:Double = 2.2
        return (time.truncatingRemainder(dividingBy: period) / period)
    }
}

fileprivate
extension Color {
    // 传入一个0-1之间的值，获得小爱同学对话的颜色。
    // 带有平滑过度。
    // 直接彩虹色太饱和了，我们降低一点。
    static func rainbow(from value: Double) throws -> Color {
        // 确保输入值在 0 到 1 之间
        guard value >= 0 && value <= 1 else {
            throw RainbowColorError.inputValueNotInZeroToOne
        }
        let durationValue = value
        
        // 将 0-1 的范围映射到彩虹颜色的不同部分
        let segments = 7 // 彩虹的颜色段数（红、橙、黄、绿、蓝、靛、紫）
        let segmentHeight = 1.0 / Double(segments)
        let segment = Int(durationValue / segmentHeight)
        
        // 调整这些值来控制整体的饱和度和亮度
        let saturationFactor = 0.7  // 降低饱和度到70%
        let brightnessFactor = 0.9  // 略微降低亮度到90%
        
        func adjustColor(red: Double, green: Double, blue: Double) -> Color {
            // 将RGB值调整为更柔和的色调
            let r = (1.0 - saturationFactor) + (red * saturationFactor)
            let g = (1.0 - saturationFactor) + (green * saturationFactor)
            let b = (1.0 - saturationFactor) + (blue * saturationFactor)
            return Color(
                red: r * brightnessFactor,
                green: g * brightnessFactor,
                blue: b * brightnessFactor
            )
        }
        
        switch segment {
        case 0:
            let offset = (durationValue - 0) / segmentHeight
            return adjustColor(red: 1, green: offset, blue: 0)
        case 1:
            let offset = (durationValue - segmentHeight) / segmentHeight
            return adjustColor(red: 1 - offset, green: 1, blue: 0)
        case 2:
            let offset = (durationValue - 2 * segmentHeight) / segmentHeight
            return adjustColor(red: 0, green: 1, blue: offset)
        case 3:
            let offset = (durationValue - 3 * segmentHeight) / segmentHeight
            return adjustColor(red: offset, green: 1, blue: 1)
        case 4:
            let offset = (durationValue - 4 * segmentHeight) / segmentHeight
            return adjustColor(red: 0, green: 1 - offset, blue: 1)
        case 5:
            let offset = (durationValue - 5 * segmentHeight) / segmentHeight
            return adjustColor(red: offset, green: 0, blue: 1)
        case 6:
            let offset = (durationValue - 6 * segmentHeight) / segmentHeight
            return adjustColor(red: 1, green: 0, blue: 1 - offset)
        default:
            return adjustColor(red: 1, green: 0, blue: 0)
        }
    }
}

enum RainbowColorError:Error,LocalizedError {
    case inputValueNotInZeroToOne
    var errorDescription: String? {
        switch self {
        case .inputValueNotInZeroToOne:
            "传入值不在0-1之间（包含端点）"
        }
    }
}
