//
//  ContentView.swift
//  PlayWithTaoBao
//
//  Created by LightningLion on 2025/2/6.
//

import SwiftUI
import RealityKit
import RealityKitContent
import WebKit
import os
import Shimmer

struct TaoBaoSearchView: View {
    var croppedImage:CGImage
    @State
    private var isDoneSearch = false
    var body: some View {
        ZStack(alignment: .center, spacing: 0) {
            // 在完成登录之前，隐藏网页
            TaoBaoSearchWebView(cgImage: croppedImage, isDoneSearch: $isDoneSearch.animation(.smooth))
                .opacity(isDoneSearch ? 1 : 0)
                .allowsHitTesting(isDoneSearch)
                .accessibilityHidden(!isDoneSearch)
            
            if !isDoneSearch {
                TaoBaoSearchLoadingView()
                    .transition(.blurReplace)
            }
        }
    }
}

// 骨架屏
fileprivate
struct TaoBaoSearchLoadingView: View {
    var body: some View {
        ScrollView(content: {
            VStack {
                    Rectangle()
                        .frame(height: 180)
                        .hidden()
                    HStack(alignment: .center, spacing: 14, content: {
                        oneList
                        oneList
                    })
                
            }
            .padding(.horizontal, 19)
        })
            .scrollDisabled(true)
            .redacted(reason: .placeholder)
            .shimmering()
    }
    @ViewBuilder
    var oneList: some View {
        VStack(alignment: .center, spacing: 8) {
            oneItem
            oneItem
            oneItem
        }
    }
    @ViewBuilder
    var oneItem: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.secondary)
                .aspectRatio(1, contentMode: .fit)
            Text("ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ")
                .font(.title3)
                .padding(.top, 8)
            Text("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                .lineLimit(1)
                .font(.title)
        }
    }
}

fileprivate
struct TaoBaoSearchWebView: View {
    var cgImage:CGImage
    @Binding
    var isDoneSearch:Bool
    @State
    private var model = WebViewModel()
    @State
    private var isWebPageLoadedTimer = Timer.publish(every: 1/30, on: .main, in: .default).autoconnect()
    @State
    private var cleanPageTimer = Timer.publish(every: 1/24, on: .main, in: .default).autoconnect()
    @State
    private var isSearchDoneTimer = Timer.publish(every: 1/10, on: .main, in: .default).autoconnect()
    @State
    private var isReadyToRecognize = false
    var body: some View {
            WebView(model: model, url: URL(string: "https://s.taobao.com/search")!)
                .clipShape(RoundedRectangle(cornerRadius: 47, style: .continuous))
                .onReceive(isWebPageLoadedTimer, perform: { _ in
                    Task { @MainActor in
                        guard !isReadyToRecognize else { return }
                        if await model.isReadyToRecgenize() {
                            isReadyToRecognize = true
                        }
                    }
                })
                .onReceive(cleanPageTimer, perform: { _ in
                    model.cleanPage()
                })
                .onReceive(isSearchDoneTimer, perform: { _ in
                    Task { @MainActor in
                        let checkIsDoneSearch = {
                            guard isReadyToRecognize else { return false }
                            return await model.isDoneSearch()
                        }
                        if await checkIsDoneSearch() {
                            do {
                                // 延迟2秒，以便页内图片完全加载好
                                try await Task.sleep(for: .seconds(2))
                                self.isDoneSearch = true
                            } catch {
                                os_log("\(error.localizedDescription)")
                                self.isDoneSearch = true
                            }
                        } else {
                            self.isDoneSearch = false
                        }
                        
                    }
                })
                .onChange(of: isReadyToRecognize, initial: true) { oldValue, newValue in
                    if oldValue == false && newValue {
                        os_log("开始上传图片")
                        model.recognizeImage(cgImage: cgImage)
                    }
                }
    }
}

@MainActor
@Observable
fileprivate
class WebViewModel {
    let webView = WKWebView()

    func isDoneSearch() async -> Bool {
        let script0 = """
(() => {
 const checkNoResultsTips = () => {
        // 匹配 tips-- 后跟随任意字母数字的类名
        const regex = /tips--[A-Za-z0-9]+/;
        const divs = document.querySelectorAll('div');
        
        const hasMatchingDiv = Array.from(divs).some(div => {
            // 检查类名和文本内容是否都匹配
            return regex.test(div.className) && 
                   div.textContent.trim() === "请输入搜索关键词";
        });
        
        // console.log('是否找到"没有找到相关宝贝"提示:', hasMatchingDiv);

        return hasMatchingDiv;
    };   
    return checkNoResultsTips();
})()     
"""
        // 检查网页中有没有<div class="loadingBox--ZkvBAg5H">
        let script1 = """
        (() => {
                    const checkLoadingBox = () => {
                        const regex = /loadingBox--[A-Za-z0-9]+/;
                        
                        // 获取所有的 div 元素
                        const divs = document.querySelectorAll('div');
                        
                        // 检查是否存在匹配的 div
                        const hasMatchingDiv = Array.from(divs).some(div => {
                            const className = div.className;
                            return regex.test(className);
                        });
                        
                        // console.log('是否找到匹配的 div:', hasMatchingDiv);
                        return hasMatchingDiv;
                    };
                    return checkLoadingBox()
        })()
        """
        do {
            
            
            let result0 = try await webView.evaluateJavaScript(script0)
            let result1 = try await webView.evaluateJavaScript(script1)
            guard let havePreSearchTip = result0 as? Bool,let haveLoadingDiv = result1 as? Bool else {
                return false
            }
            // 图片还没有上传完成，或还没有得到搜索结果
            if havePreSearchTip || haveLoadingDiv {
                return false
            } else {
                return true
            }
        } catch {
            return false
        }
    }

    func recognizeImage(cgImage:CGImage) {
        guard let toBase64:String = UIImage(cgImage: cgImage).jpegData(compressionQuality: 1)?.base64EncodedString() else {
            os_log("序列化图片失败")
            return
        }
        let script = """
    (() => {
      function base64ToBlob(base64String) {
        const base64WithoutPrefix = base64String;

        // 将base64转换为二进制数据
        const binaryString = atob(base64WithoutPrefix);
        const bytes = new Uint8Array(binaryString.length);

        for (let i = 0; i < binaryString.length; i++) {
          bytes[i] = binaryString.charCodeAt(i);
        }

        return new Blob([bytes], { type: "image/jpeg" });
      }

      // 模拟文件上传
      function simulateFileUpload(base64String) {
        // 获取file input元素
        const fileInput = document.querySelector("#image-search-custom-file-input");
        if (!fileInput) {
          throw new Error("未找到目标文件输入框元素");
        }

        // 创建DataTransfer对象
        const dataTransfer = new DataTransfer();

        // 从base64创建File对象
        const blob = base64ToBlob(base64String);
        const file = new File([blob], "image.jpg", { type: "image/jpeg" });

        // 添加文件到DataTransfer
        dataTransfer.items.add(file);

        // 将文件设置到input元素
        fileInput.files = dataTransfer.files;

        // 触发change事件
        const event = new Event("change", { bubbles: true });
        fileInput.dispatchEvent(event);
      }

      // 在这里插入图片的base64
      simulateFileUpload("\(toBase64)");

      const timerId = setInterval(() => {
        // 使用 querySelector，匹配class和id
        const confirmSearchButton = document.querySelector(
          "div#image-search-upload-button.upload-button.upload-button-active"
        );
        if (confirmSearchButton) {
          confirmSearchButton.click();
          console.log("已上传图片");
          clearInterval(timerId);
          let clikCloseUploadBoxButtonCount = 0;
          const closeUploadBoxTimerId = setInterval(() => {
            // 查找 class="back-button" 的 div
            const backButton = document.querySelector("div.back-button");
            if (backButton) {
              backButton.click(); // 点击该 div
    if (clikCloseUploadBoxButtonCount >= 88) { // 多给一点时间，不然可能点不掉
              clearInterval(closeUploadBoxTimerId);
    }
                      clikCloseUploadBoxButtonCount ++
              console.log("已点击 back-button 元素。");
            } else {
              console.log("未找到 back-button 元素。");
            }
          });
        } else {
          console.log("未找到上传按钮");
        }
      }, 100);
    })();

    """
        webView.evaluateJavaScript(script)
    }
    func cleanPage() {
        let script = """
(function() {
    // 删除 class="tb-toolkit-new" 的 div
    const toolkitDivs = document.querySelectorAll('div.tb-toolkit-new');
    toolkitDivs.forEach(div => div.remove());

    // 删除 class="site-nav site-nav-status-login site-nav-status-logout" 的 div
    const navDivs = document.querySelectorAll('div.site-nav.site-nav-status-login, div.site-nav.site-nav-status-logout');
    navDivs.forEach(div => div.remove());


 // 查找所有 class 以 suggestWarpAdaptMod 开头的 div
    const searchBarDivs = document.querySelectorAll('div[class^="suggestWarpAdaptMod"]');
    searchBarDivs.forEach(div => div.remove());

 // 查找所有 class 以 sortFilterWrapper 开头的 div
    const sortFilterDivs = document.querySelectorAll('div[class^="sortFilterWrapper"]');
        sortFilterDivs.forEach(div => div.remove());

// 设置到两列商品
(function() {
    // 查找所有 class 包含 tbpc-col-lg-12 的 div
    const divs = document.querySelectorAll('div[class*="tbpc-col-lg-12"]');
    divs.forEach(div => {
        div.style.flex = "0 0 50%";
        div.style.maxWidth = "50%";
        div.style.paddingLeft = "20px";
        div.style.paddingRight = "20px";
        console.log("已设置 div 的 flex 和 max-width 样式。");
    });
})();

// 往下滑之后，避免顶部Logo栏的白色背景
(function() {
    // 删除 class 以 headerWrapAdaptMod 开头的 div
    const headerDivs = document.querySelectorAll('div[class^="tbpc-layout headerWrapAdaptMod"]');
    headerDivs.forEach(div => div.style.backgroundColor = "transparent");
    console.log("已改透明 class 以 headerWrapAdaptMod 开头的 div。");
})();

//清理左侧边距
(function() {
    // 查找所有 class 以 pageContent 开头的 div
    const divs = document.querySelectorAll('div[class^="tbpc-layout"]');
    divs.forEach(div => {
        div.style.paddingLeft = "0"; // 设置左侧 padding 为 0
        console.log("已将 class 以 pageContent 开头的 div 的左侧 padding 设置为 0。");
    });
})();

//缩小以满足尺寸要求
(function() {
    // 查找所有 class 以 leftContent 开头的 div
    const divs = document.querySelectorAll('div[class^="leftContent"]');
    divs.forEach(div => {
        div.style.backgroundColor = "transparent";
        div.style.transformOrigin = "top center"; // 设置缩放锚点为顶部中心
        div.style.transform = "scale(0.32) translateX(50px)"; // 缩小并向右偏移 50px
        console.log("已对 class 以 leftContent 开头的 div 应用 transform。");
    });
})();

//清理商品Grid的背景色
(function() {
    // 查找所有 class 以 content-- 开头的 div
    const divs = document.querySelectorAll('div[class^="content--"]');
    divs.forEach(div => {
        div.style.backgroundColor = "transparent";
    });
})();

//让商品标题大一点（这个尺寸是在考虑了transform后的）
(function() {
    // 查找所有 class 以 content-- 开头的 div
    const divs = document.querySelectorAll('div[class^="title--"]');
    divs.forEach(div => {
        div.style.color = "white";
        div.style.fontSize = "56px";
        div.style.lineHeight = "69px";
        div.style.height = "222px";
        div.style.paddingTop = "20px";
    });
})();
})();
"""
        webView.evaluateJavaScript(script)
    }
    func isReadyToRecgenize() async -> Bool {
        let script = """
(function() {
    // 检测是否存在 <div>请输入搜索关键词</div>
    const divs = document.querySelectorAll('div');
    let found = false;

    divs.forEach(div => {
        if (div.textContent.trim() === "请输入搜索关键词") {
            found = true;
        }
    });

    if (found) {
        return true;
    } else {
        return false;
    }
})();
"""
        guard let boolResult = try? await webView.evaluateJavaScript(script) as? Bool else {
            os_log("脚本返回的数据类型不对")
            return false
        }
        return boolResult
    }
}

@MainActor
@Observable
fileprivate
class WebViewDelegate:NSObject, WKUIDelegate, WKNavigationDelegate {
    
}

// 创建一个WKWebView
fileprivate
struct WebView: UIViewRepresentable {
    typealias UIViewType = WKWebView
    @State
    var model:WebViewModel
    let url: URL
    private
    let delegate = WebViewDelegate()
    

    func makeUIView(context: Context) -> WKWebView {
        let webView = model.webView
        webView.navigationDelegate = delegate
        webView.uiDelegate = delegate
        webView.load(URLRequest(url: url))
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.isOpaque = false
        webView.isInspectable = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 更新UIView
    }
}
