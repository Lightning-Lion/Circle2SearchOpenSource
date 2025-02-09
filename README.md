
---

# 如何运行

该项目使用手势追踪及主摄像头访问，无法在模拟器里体验功能，需要Vision Pro真机。

项目配置方法与[CropFrameOpenSource](https://github.com/Lightning-Lion/CropFrameOpenSource)一致，可以参考它。

请使用右手画圈，左手点击按钮。

---

# 抛砖引玉

代码有很多地方能优化的，欢迎您讨论。您不用「慢悠悠的发邮件等回复」。

您直接来[找我](https://www.feishu.cn/invitation/page/add_contact/?token=d4br5909-0f29-4e22-adf8-aebc814e7c5d&amp;unique_id=Zz2qoXiCUqhYjKsrHBrGnA==)，给您拉视频会议，马上解决，（免费）。

如果您没有Enterprise APIs，但**想更多了解它用起来是什么样的**，也可以加我，我可以为您提供更多实机演示视频。

---

# 无障碍

本App需要您有右手大拇指、右手食指才能正常交互。

---

# 代码细节

当我们表示3D点时，我们总是使用RealityKit坐标系。

当我们表示2D点时，我们总是假设平面的左上角为(0,0)，平面的右下角为(宽,高)。

---

# 不完善

- 现有版本对捏和的判定很粗糙，在暗光情况下，由于指尖定位的不准确，会让画出来的线断断续续的。

    画出来的线断断续续的，就会让每一个小线段都被误认为是一个独立的Circle to search请求，带来「碎片」。

    当前版本的判断逻辑是指尖距离小于0.015米，就算作捏合。

    建议后续版本改为使用原生的`.gesture(DragGesture().targetedToAnyEntity())`，来判断捏合状态。

- 画出来的圈没有做闭合处理。

    本Demo中画出来的圈是用于确定边界框的。

    但如果需要做画圈区域截图，则需要让画出来的圈是闭合的。

    可以将圈的最后一个点和圈的第一个点连起来，实现闭合。

- 容易误触
    
    没有做防误触处理。右手在点按钮的时候，会被认为是在捏合画圈，造成误触。

    建议使用拖曳手势，因为拖曳手势会自动区分是在点击UI中的按钮，还是在RealityKit的Scene中捏和。比如在`.gesture(DragGesture().targetedToAnyEntity())`检测到拖曳的时候，才画圈。

- 就算不考虑误触，理论上左手或右手都可以画圈

    但如果需要支持左右手<u>同时</u>画圈，需要改`struct ShowSearchWhenRelease: ViewModifier {`，因为目前它只观察最新的一个圈，不支持同时画两个圈。

---

# 第三方引用

创意参考 [https://www.youtube.com/watch?v=az5QL_NLBvg](https://www.youtube.com/watch?v=az5QL_NLBvg)

`DoneCircleSound.m4a`音效素材来自于剪影音效库，如果您需要商业使用请购买音频版权。

粒子画圈功能参考 [Creating a spatial drawing app with RealityKit](https://developer.apple.com/documentation/RealityKit/creating-a-spatial-drawing-app-with-realitykit)


商品识别功能由淘宝提供（网页版淘宝搜索的“搜同款”功能）。

App图标由豆包生成。

第三方软件包：

[OpenCV-SPM](https://github.com/yeatse/opencv-spm.git) [许可证](https://github.com/yeatse/opencv-spm/blob/main/LICENSE)

[SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON.git) [许可证](https://github.com/SwiftyJSON/SwiftyJSON/blob/master/LICENSE)

---

# 免责声明

本项目仅作为抛砖引玉，不保证代码质量，在生产环境中使用造成的损失需要您自己负责。

---

# 独立性

淘宝并未赞助本项目。
