//
//  ImmersiveView.swift
//  Circle2Search
//
//  Created by LightningLion on 2025/1/28.
//

import SwiftUI
import RealityKit
import RealityKitContent
import MixedRealityKit
import os

struct ImmersiveView: View {
    var circleManager:CircleManager
    @State
    private var vm = ImmersiveViewModel()
    @State
    private var drawingController: DrawingController?
      var body: some View {
          CameraPassthroughMR(attachments:$vm.attachments, liveFrame: $vm.liveFrame) { content in
              vm.content = content
              vm.contentPack = RealityViewContentPack(realityViewContent: content)
          }
          // 启用捏合画圈
          .modifier(EnableSparkleBrush(circleManager: circleManager, drawingController: $drawingController, contentPack: $vm.contentPack))
          // 随时间变换笔尖颜色
          .modifier(ChangeColorOvertime(mod: $drawingController))
          // 在松手后显示圈起来的图片
          .modifier(ShowCircledImage(liveFrame: vm.liveFrame, circleManager: circleManager,addImage: vm.addImage))
      }
    
}


@MainActor
@Observable
fileprivate
class ImmersiveViewModel {
    var liveFrame: FrameData?
    var cameraImage:CGImage? {
        liveFrame?.cameraPhoto
    }
    var mrData:MRData? {
        liveFrame?.mrData
    }
    var content:RealityViewContent? = nil
    var contentPack:RealityViewContentPack? = nil
    var attachments:[AttachmentComponent] = []
    // 存储已添加到场景中的实体(图像、搜索结果面板)
    var circleRepresentatives:[Entity] = []
    func addImage(imageData:CircledImageData,searchPanelData:SearchPanelData) {
        do {
            // 先remove last，不然视野中全充斥着一堆窗口了，层层叠叠
            if let lastItem = circleRepresentatives.last,let lastIndex = circleRepresentatives.lastIndex(of: lastItem) {
                circleRepresentatives.remove(at: lastIndex)
                // 我已独立（不被存储）了，接下来开始动画
                fadeOut(for: lastItem)
            }
            let representativeEntity = try addImageInner(imageData:imageData, searchPanelData:searchPanelData)
            self.circleRepresentatives.append(representativeEntity)
        } catch {
            os_log("\(error.localizedDescription)")
        }
    }
    private
    func fadeOut(for entity:Entity) {
         let opacityAction = FromToByAction<Float>(to: 0.0,
                                                   timing: .easeInOut,
                                                   isAdditive: false)
        do {
            let opacityAnimation = try AnimationResource
                .makeActionAnimation(for: opacityAction,
                                     duration: 0.3,
                                     bindTarget: .opacity)
           
            entity.playAnimation(opacityAnimation)
        } catch {
            os_log("\(error.localizedDescription)")
        }
    }
    private
    func addImageInner(imageData:CircledImageData,searchPanelData:SearchPanelData) throws -> Entity {
        guard let content else {
            os_log("RealityViewContent没有准备好")
            throw AddImageError.realitySceneNotReady
        }
        let oneCircleEntity = Entity()
        content.add(oneCircleEntity)
        let imageEntity = Entity()
        oneCircleEntity.addChild(imageEntity, preservingWorldTransform: true)
        imageEntity.components.set(attachments.queryNewItem(attachmentView: AnyView(CircledImageView(size: .init(width: imageData.size.0, height: imageData.size.1), image: imageData.croppedImage))))
        //        entity.components.set(attachments.queryNewItem(attachmentView: AnyView(TestAttachmentView())))
        
        imageEntity.setTransformMatrix(imageData.transform.matrix, relativeTo: nil)
        
        
        let searchResultPanelEntity = Entity()
        oneCircleEntity.addChild(searchResultPanelEntity, preservingWorldTransform: true)
        searchResultPanelEntity.components
            .set(
                attachments.queryNewItem(
                    attachmentView: AnyView(
                        ResultPanelView(
                            size: .init(
                                width: searchPanelData.size.0,
                                height: searchPanelData.size.1
                            ),
                            croppedImage: imageData.croppedImage
                        )
                    )
                )
            )
        //        entity.components.set(attachments.queryNewItem(attachmentView: AnyView(TestAttachmentView())))
        
        searchResultPanelEntity.setTransformMatrix(searchPanelData.transform.matrix, relativeTo: nil)
        return oneCircleEntity
    }
    enum AddImageError:Error,LocalizedError {
        case realitySceneNotReady
        var errorDescription: String? {
            switch self {
            case .realitySceneNotReady:
                "RealitySceneNotReady"
            }
        }
    }
}
