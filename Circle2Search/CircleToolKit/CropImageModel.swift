import SwiftUI
import RealityFoundation
import MixedRealityKit
import os
import opencv2

// 表示一个四边形，因为从3D投影来的，很可能不是矩形
struct Quadrilateral2D {
    let topLeft:CGPoint
    let topRight:CGPoint
    let bottomRight:CGPoint
    let bottomLeft:CGPoint
}


struct Rect2DIn3D {
    let topLeft:SIMD3<Float>
    let topRight:SIMD3<Float>
    let bottomRight:SIMD3<Float>
    let bottomLeft:SIMD3<Float>
    func toRect2D(converFunction:@escaping (SIMD3<Float>) throws -> CGPoint) rethrows -> Quadrilateral2D {
        Quadrilateral2D(topLeft: try converFunction(topLeft), topRight: try converFunction(topRight), bottomRight: try converFunction(bottomRight), bottomLeft: try converFunction(bottomLeft))
    }
}


class CropImageModel {
    typealias ImageViewPhysicalSize = (Float,Float)

    func cropImage(vertices:Rect2DIn3D,frame:FrameData,photoViewPhysicalSize:ImageViewPhysicalSize) -> CGImage? {
        let deviceTransform:Transform = frame.deviceTransform
        do {
            let quadrilateral2D:Quadrilateral2D = try vertices.toRect2D { point3D in
                let point2D = try MRPoint2D3DConverterFast.worldPointToCameraPoint(worldPoint: point3D, deviceTransform: deviceTransform, mrData: frame.mrData)
                return point2D
            }
            guard let croppedImage:CGImage = twoDCropImage(quadrilateral: quadrilateral2D, photo: frame.cameraPhoto, photoViewPhysicalSize: photoViewPhysicalSize) else {
                os_log("CGImage裁剪图片失败")
                return nil
            }
            return croppedImage
        } catch {
            os_log("\(String(describing: error))")
            return nil
        }
        
    }
    
    private
    func twoDCropImage(quadrilateral:Quadrilateral2D,photo:CGImage,photoViewPhysicalSize:ImageViewPhysicalSize) -> CGImage? {
        // ---
        // 本来是先以四边形裁剪，然后再扭曲到矩形
        // 现在发现用OpenCV直接以四边形的四个点，做扭曲到矩形的四个点，就可以了
        // ---
        // 不管物理尺寸多少，总是使用1080P
        let photoViewImageSize = resizeTo1080P(width: photoViewPhysicalSize.0, height: photoViewPhysicalSize.1)
        os_log("要求的图片的尺寸\(photoViewImageSize.0),\(photoViewImageSize.1)")
        // 然后扭曲到矩形，以便PhotoView使用
        guard let perspectivedImage:CGImage = quadrilateralImageToRectImage(quadrilateralImage: photo, quadrilateral2D: quadrilateral, outputRectImageSize: toCGSize(inputValue: photoViewImageSize)) else {
            os_log("使用OpenCV完成透视变换失败")
            return nil
        }
        os_log("最终得到的图片的尺寸\(perspectivedImage.width),\(perspectivedImage.height)")
        return perspectivedImage
    }
    
    
    // 保持比例不变，最短边总是1080像素
    // 输入和输出都是“宽，高”
    private
    func resizeTo1080P(width: Float, height: Float) -> (Float, Float) {
        let targetMin: Float = 1080
        
        if width < height {
            // 如果宽度是最短边
            let aspectRatio = height / width
            let newHeight = targetMin * aspectRatio
            return (targetMin, newHeight)
        } else {
            // 如果高度是最短边
            let aspectRatio = width / height
            let newWidth = targetMin * aspectRatio
            return (newWidth, targetMin)
        }
    }
    private
    func toCGSize(inputValue:(Float, Float)) -> CGSize {
        let widthCGFloat:CGFloat = CGFloat(inputValue.0)
        let heightCGFloat:CGFloat = CGFloat(inputValue.1)
        return CGSize(width: widthCGFloat, height: heightCGFloat)
    }
}

fileprivate
func quadrilateralImageToRectImage(quadrilateralImage:CGImage,quadrilateral2D:Quadrilateral2D,outputRectImageSize:CGSize) -> CGImage? {
    os_log("四边形\(String(describing: quadrilateral2D))")
    // 1. 创建目标矩形的四个角点
    let destTopLeft = CGPoint(x: 0, y: 0)
    let destTopRight = CGPoint(x: outputRectImageSize.width, y: 0)
    let destBottomRight = CGPoint(x: outputRectImageSize.width, y: outputRectImageSize.height)
    let destBottomLeft = CGPoint(x: 0, y: outputRectImageSize.height)
    
    // 2. 创建源点和目标点数组
    let sourcePoints = [
        quadrilateral2D.topLeft,
        quadrilateral2D.topRight,
        quadrilateral2D.bottomRight,
        quadrilateral2D.bottomLeft
    ]
    
    let destPoints = [
        destTopLeft,
        destTopRight,
        destBottomRight,
        destBottomLeft
    ]
    do {
        
        // 3. 计算透视变换矩阵
        let perspectiveTransform = try PerspectiveTransform.getPerspectiveTransform(src: sourcePoints, dst: destPoints)
        
        let outputSize:Size2i = PerspectiveTransform.cgSizeToSize2i(outputRectImageSize)
        os_log("要求输出尺寸：\(outputSize.description())")
        // 7. 获取结果图像
        let transformedImage = PerspectiveTransform.warpPerspective(image: quadrilateralImage, perspectiveMatrix: perspectiveTransform, outputSize: outputSize)
        os_log("图片输出尺寸：\(transformedImage.width), \(transformedImage.height)")
         return transformedImage
    } catch {
        os_log("\(String(describing:error))")
        return nil
    }
}
