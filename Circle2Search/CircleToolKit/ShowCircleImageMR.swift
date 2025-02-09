//
//  ShowCircleImageMR.swift
//  Circle2Search
//
//  Created by LightningLion on 2025/2/1.
//

import SwiftUI
import RealityKit
import MixedRealityKit
import os
import AVKit

struct CircledImageData:Identifiable,Hashable {
    let id = UUID()
    let timestamp = Date.now
    let transform:Transform
    let size:(Float,Float) // 宽高
    let croppedImage:CGImage
}

extension CircledImageData {
    static func == (lhs: CircledImageData, rhs: CircledImageData) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct SearchPanelData:Identifiable,Hashable {
    let id = UUID()
    let timestamp = Date.now
    let transform:Transform
    let size:(Float,Float) // 宽高
}

extension SearchPanelData {
    static func == (lhs: SearchPanelData, rhs: SearchPanelData) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ShowCircledImage: ViewModifier {
    var liveFrame: FrameData?
    var circleManager:CircleManager
    var addImage:(CircledImageData,SearchPanelData)->()
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow)
    private var openWindow
    @State
    private var avAudioPlayer = try! AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "DoneCircleSound", withExtension: "m4a")!)
    @State
    private var imageCropModel = CropImageModel()
    func body(content: Content) -> some View {
        content
            .task(id: "onLoad", {
                do {
                    // 配置音频会话
                    try AVAudioSession.sharedInstance().setCategory(.playback)
                    try AVAudioSession.sharedInstance().setActive(true)
                    
                    avAudioPlayer.prepareToPlay()
                } catch {
                    os_log("\(error.localizedDescription)")
                }
            })
            .onChange(of: circleManager.circles.last?.isDone, initial: true) { oldValue, isDone in
                Task { @MainActor in
                    // 要的平面是这样的
                    // 平面的+Y方向与设备的+Y方向一致
                    // 平面贴合圈所在的平面
                    // 平面的尺寸，包含了圈
                    os_log("观察到了什么")
                    if let isDone,isDone == true,
                       let newestCircle = circleManager.circles.last {
                        playSound()
                        caculateImagePanel(newestCircle:newestCircle)
                    }
                }
            }
    }
    // 弱光/手遮挡的情况下，可能会出现断断续续的圈
    // 总是播放音效，让用户知道圈“碎”了
    func playSound() {
        avAudioPlayer.play()
    }
    func caculateImagePanel(newestCircle:SpatialCircle) {
        
        os_log("有一个圈画好了")
        guard let liveFrame else {
            os_log("相机画面没准备好")
            return
        }
        
        
        let deviceTransform:simd_float4x4 = liveFrame.deviceTransform.matrix
        
        let transformer = OrientedPanelTransformer()
        // 重新采样，以便得到均匀的点间距
        let reSampledPoints = transformer.reparameterizeCurve(newestCircle.points, toCount: 1024)
        
        
        
        
        // 平均取3个点，代表整个曲线。
        // 把曲线分成三段，并且计算每段的平均点。
        // 这三个点负责表征曲线所在的平面。
        do {
            let (avg1, avg2, avg3) = try PointCloudProcessor.processPoints(reSampledPoints)
            guard let center = transformer.computeCenter(of: reSampledPoints) else {
                os_log("无法计算中心点")
                return
            }
            
            let panelTransform = try transformer.findPanelTransform(
                points: [avg1, avg2, avg3],
                center: center,
                deviceTransform: deviceTransform
            )
            os_log("成功计算panelTransform")
            // 接下来计算尺寸，确保所有点都可以在这个尺寸内
            // 这些点是panel内的局部点，它们的Z总是为0.
            let pointsOnPanel:[SIMD3<Float>] = try newestCircle.points.map { point in
                try projectPoint(point, onto: panelTransform)
            }
            guard let maxY = pointsOnPanel.max(by: {
                $0.y < $1.y
            }),let minY = pointsOnPanel.min(by: {
                $0.y < $1.y
            }),let maxX = pointsOnPanel.max(by: {
                $0.x < $1.x
            }),let minX = pointsOnPanel.min(by: {
                $0.x < $1.x
            }) else {
                os_log("找不到边界点")
                return
            }
            os_log("投影出的点有：\(pointsOnPanel.shuffled().prefix(20))")
            os_log("maxY:\(maxY.y),minY:\(minY.y),maxX:\(maxX.x),minX:\(minX.x)")
            let width:Float = maxX.x-minX.x
            let height:Float = maxY.y-minY.y
            os_log("得到的panel的尺寸是：\(width.formatted(.number)),\(height.formatted(.number))")
            
            let croppedImage = try doCrop(transform: Transform(matrix: panelTransform), size: (width,height), frame: liveFrame)
            let circledImageData = CircledImageData(transform: Transform(matrix: panelTransform), size: (width,height), croppedImage: croppedImage)
            
            let (searchPanelTransform,searchPanelSize) = getPanelTransformAndSize(imageTransform: Transform(matrix: panelTransform), imageSize: (width,height), deviceTransform: Transform(matrix: deviceTransform))
            let searchPanelData = SearchPanelData(transform: searchPanelTransform, size: searchPanelSize)
            addImage(circledImageData,searchPanelData)
        } catch {
            os_log("Error: \(error.localizedDescription)")
        }
        
    }
    func doCrop(transform:Transform,size:(Float,Float),frame:FrameData) throws -> CGImage {
        let topLeft:SIMD3<Float> = Transform(matrix: calculateTransformMatrix(parentTransform: transform, localPosition: [-size.0/2,size.1/2,0])).translation
        let topRight:SIMD3<Float> = Transform(matrix: calculateTransformMatrix(parentTransform: transform, localPosition: [size.0/2,size.1/2,0])).translation
        let bottomRight:SIMD3<Float> = Transform(matrix: calculateTransformMatrix(parentTransform: transform, localPosition: [size.0/2,-size.1/2,0])).translation
        let bottomLeft:SIMD3<Float> = Transform(matrix: calculateTransformMatrix(parentTransform: transform, localPosition: [-size.0/2,-size.1/2,0])).translation
        guard let croppedImage = imageCropModel.cropImage(vertices: .init(topLeft: topLeft, topRight: topRight, bottomRight: bottomRight, bottomLeft: bottomLeft), frame: frame, photoViewPhysicalSize: CropImageModel.ImageViewPhysicalSize(size)) else {
            throw DoCropError.failedToCrop
        }
        return croppedImage
    }
    enum DoCropError:Error,LocalizedError {
        case failedToCrop
        var errorDescription: String? {
            switch self {
            case .failedToCrop:
                "裁剪图片失败"
            }
        }
    }
    
    func getPanelTransformAndSize(imageTransform:Transform,imageSize:(Float,Float),deviceTransform:Transform) -> (Transform,(Float,Float)) {
        // 视图的尺寸，不能太小，不然UI元素显示不下了
        let panelViewSize:(Float,Float) = (0.3,0.5)
        // 放在圈的右侧
        // 间距0.05
        let spacing:Float = 0.05
        // 图片右半侧的宽度 + 间距 + 我自己左半侧的宽度
        let centerX:Float = imageSize.0 / 2 + spacing + panelViewSize.0 / 2
        // 我和图像顶部对齐
        // 图像上半部的高度 = 我的顶部高度
        // 我的中心高度 = 我的顶部高度 - 我的高度的一半
        let centerY:Float = (imageSize.1 / 2) - panelViewSize.1 / 2
        let centerPosition:SIMD3<Float> = [centerX, centerY, 0]
        // 转换到全局位置
        let toGlobalPosition:SIMD3<Float> = Transform(matrix: calculateTransformMatrix(parentTransform: imageTransform, localPosition: centerPosition)).translation
        // 看向用户，因为用户可能圈了桌面上的一个东西，总不能让搜索结果面板也平铺在桌面上吧？那用户怎么阅读？
        var finalTransform:Transform = Transform.look(at: deviceTransform.translation, from: toGlobalPosition, upVector: [0,1,0], shouldFilpZ: false)
        return (finalTransform,panelViewSize)
    }
}

@MainActor
@Observable
class ViewRealitySize {
    // 1 meter = 1360 points
    // https://www.createwithswift.com/understanding-real-world-sizes-for-visionos/
    fileprivate
    var viewSize:CGSize
    // 输入以米为单位的尺寸，兼容RealityKit
    init(width:Float,height:Float) {
        let toSwiftUISize = CGSize(width:ViewRealitySize.realityKitSizeToSwiftUISize(realityKitSize: width),height: ViewRealitySize.realityKitSizeToSwiftUISize(realityKitSize: height))
        self.viewSize = toSwiftUISize
    }
    private
    static
    func realityKitSizeToSwiftUISize(realityKitSize:Float) -> CGFloat {
        CGFloat(realityKitSize * 1360)
    }
}


struct CircledImageView: View {
    var size:ViewRealitySize
    var image:CGImage
    @State
    private var opacity = 0.0
    var body: some View {
        Image(image, scale: 1, label: Text("圈出的图片"))
            .resizable()
            .frame(width: size.viewSize.width, height: size.viewSize.height, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: 50, style: .continuous))
            .opacity(opacity)
            .task(id: "onLoad", { withAnimation(.easeIn(duration: 0.3), { opacity = 1 }) })
    }
}


struct ResultPanelView: View {
    var size:ViewRealitySize
    var croppedImage:CGImage
    init(size: ViewRealitySize,croppedImage:CGImage) {
        self.size = size
        self.croppedImage = croppedImage
        // 不用负号，因为.offset(z:是正的算面向用户的方向
        self.offsetZ = size.viewSize.height
    }
    @State
    private var opacity = 0.0
    @State
    private var ratationDegrees:Double = 90
    @State
    private var offsetZ:Double
    var body: some View {
        Color.blue.opacity(0.1)
            .overlay(content: {
                // 要更换别的行为，直接替换这里的就可以
                TaoBaoSearchView(croppedImage: croppedImage)
            })
            .glassBackgroundEffect()
            .frame(width: size.viewSize.width, height: size.viewSize.height, alignment: .center)
            .opacity(opacity)
            // 先躺下
            .rotation3DEffect(.degrees(ratationDegrees), axis: (1,0,0), anchor: .bottom)
            // 再向前（朝用户近的方向）挪一个身子
            .offset(z: offsetZ)
            .task(id: "onLoad", {
                // 自己立起来
                withAnimation(.easeOut(duration: 0.3), {
                    opacity = 1
                })
                withAnimation(.spring(.bouncy(duration: 0.7))) {
                    ratationDegrees = 0
                    offsetZ = 0
                }
            })
    }
}
