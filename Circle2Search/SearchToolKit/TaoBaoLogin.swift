import SwiftUI
import RealityKit
import RealityKitContent
import WebKit
import os

struct TaoBaoLoginView: View {
    @Binding
    var isDoneLogin:Bool
    @State
    private var model = WebViewModel()
    @State
    private var isDoneLoginTimer = Timer.publish(every: 0.1, on: .main, in: .default).autoconnect()
    var body: some View {
            WebView(model: model, url: URL(string: "https://login.taobao.com/member/login.jhtml?redirectURL=http%3A%2F%2Fi.taobao.com%2Fmy_itaobao")!)
                .clipShape(RoundedRectangle(cornerRadius: 47, style: .continuous))
                .onReceive(isDoneLoginTimer, perform: { _ in
                    self.isDoneLogin = model.isDoneLogin()
                })
    }
}

@MainActor
@Observable
fileprivate
class WebViewModel {
    let webView = WKWebView()
    
    // 登录完成后会跳转到这个页面，这就算完成了
    func isDoneLogin() -> Bool {
        let targetURL = "i.taobao.com/my_itaobao"
        guard let currentURL = webView.url else {
            return false
        }
        guard currentURL.absoluteString.contains(targetURL) else {
            return false
        }
        return true
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
        webView.isInspectable = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 更新UIView
    }
}
