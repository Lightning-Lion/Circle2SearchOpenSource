//
//  ContentView.swift
//  Circle2Search
//
//  Created by LightningLion on 2025/1/28.
//

import SwiftUI
import RealityKit
import RealityKitContent
import os

struct ContentView: View {
    @State
    private var isDoneLogin = false
    @State
    private var allowScale = false
    var body: some View {
        VStack {
            
                    if !isDoneLogin {
                        TaoBaoLoginView(isDoneLogin: $isDoneLogin.animation(.smooth))
                            .toolbar {
                                ToolbarItemGroup(placement: .bottomOrnament) {
                                    VStack {
                                        Text("请先在上方网页中完成淘宝登录")
                                            .bold()
                                        Text("如需扫码，请截图扫")
                                            .foregroundStyle(.secondary)
                                            .font(.footnote)
                                    }
                                }
                            }
                            .frame(width: 1 * 1360, height: 0.7 * 1360)
                    } else {
                        
                        VStack {
                            Text("Hello, world!")
                            ToggleImmersiveSpaceButton()
                        }
                        .modifier(DynamicResizability(allowResize: $allowScale))
                    }
            
        }
        // 延迟1秒，以允许窗口缩小的动画完成
        .modifier(DelayOneSecondSync(inputValue: $isDoneLogin, outputValue: $allowScale))
    }
}


// 输入值延迟一秒反映到输出值
struct DelayOneSecondSync<V:Equatable>: ViewModifier {
    @Binding
    var inputValue:V
    @Binding
    var outputValue:V
    @State
    private var delayTask:Task<Void,Never>?
    func body(content: Content) -> some View {
        content
            .onChange(of: inputValue, initial: true) { oldValue, newValue in
                delayTask?.cancel()
                delayTask = Task { @MainActor in
                    do {
                        try await Task.sleep(for: .seconds(1))
                        outputValue = newValue
                    } catch {
                        os_log("已取消")
                    }
                }
            }
    }
}

// 使用.frame来限制尺寸，当不需要限制的时候切换为nil
struct DynamicResizability: ViewModifier {
    @Binding
    var allowResize:Bool
    func body(content: Content) -> some View {
        
        
        VStack(alignment: .center, spacing: 0, content: {
            Spacer()
            HStack(alignment: .center, spacing: 0) {
                Spacer()
                content
                Spacer()
            }
            Spacer()
        })
        // nil代表不限制frame，允许自由调整
        .frame(width: allowResize ? nil : 0.23 * 1360, height: allowResize ? nil : 0.2 * 1360)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
