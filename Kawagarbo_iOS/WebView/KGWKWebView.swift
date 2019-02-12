//
//  KGWKWebView.swift
//  KawagarboExample
//
//  Created by 温一鸿 on 2018/9/12.
//  Copyright © 2018年 Moirig. All rights reserved.
//

import UIKit
import WebKit

private let kProgressObserverKey: String = "estimatedProgress"
private let kTitleObserverKey: String = "title"

public class KGWKWebView: WKWebView {
    
    weak var webViewDelegate: KGWebViewDelegate?
    
    var nativeApiManager: KGNativeApiManager?
    
    var alertCompletionHandler: (() -> Void)?
    var confirmCompletionHandler: ((Bool) -> Void)?
    var textCompletionHandler: ((String?) -> Void)?
    
    public var config: KGConfig! {
        get { return KGConfig() }
        set {
            progressView.progressTintColor = newValue.getProgressTintColor
            
            if #available(iOS 9.0, *) {
                customUserAgent = KGWKWebView.originalUserAgent + newValue.getUserAgent
            }
        }
    }
        
    static var originalUserAgent: String {
        let webview = UIWebView(frame: CGRect.zero)
        let userAgent = webview.stringByEvaluatingJavaScript(from: "navigator.userAgent")
        return userAgent ?? ""
    }
        
    private lazy var progressView: UIProgressView = {
        let progressView = UIProgressView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 0))
        progressView.alpha = 0
        
        return progressView;
    }()
    
    private static let sharedProcessPool: WKProcessPool = WKProcessPool()
    
    static var defaultConfiguration: WKWebViewConfiguration {
        let defaultConfiguration = WKWebViewConfiguration()
        
        if #available(iOS 10.0, *) {
            defaultConfiguration.mediaTypesRequiringUserActionForPlayback = .all
        }
        if #available(iOS 9.0, *) {
            defaultConfiguration.requiresUserActionForMediaPlayback = false
            defaultConfiguration.websiteDataStore = WKWebsiteDataStore.default()
        }
        
        defaultConfiguration.allowsInlineMediaPlayback = true
        defaultConfiguration.processPool = sharedProcessPool
        
        defaultConfiguration.userContentController = WKUserContentController()        
        return defaultConfiguration
    }
    
    deinit {
        removeObserver(self, forKeyPath: kProgressObserverKey)
        removeObserver(self, forKeyPath: kTitleObserverKey)

        stopLoading()
        navigationDelegate = nil
        uiDelegate = nil
    }
    
    static var webView: KGWKWebView {
        return KGWebViewManager.createWebView
    }
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        setupWebView()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupWebView() {
        allowsBackForwardNavigationGestures = true
        
        navigationDelegate = self
        uiDelegate = self
        
        addObserver(self, forKeyPath: kProgressObserverKey, options: [.old, .new], context: nil)
        addObserver(self, forKeyPath: kTitleObserverKey, options: [.old, .new], context: nil)
        
        addSubview(progressView)
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == kProgressObserverKey {
            progressView.alpha = 1
            progressView .setProgress(Float(estimatedProgress), animated: true)
            if estimatedProgress >= 1.0 {
                UIView.animate(withDuration: 0.3, delay: 0.3, options: .curveEaseOut, animations: {
                    self.progressView.alpha = 0
                }) { (finished) in
                    self.progressView .setProgress(0, animated: true)
                }
            }
        }
        else if keyPath == kTitleObserverKey {
            webViewDelegate?.webViewTitleChange(self)
        }
        else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
}

// MARK: - WKNavigationDelegate
extension KGWKWebView: WKNavigationDelegate {
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let allowed = webViewDelegate?.webView(self, shouldStartLoadWith: navigationAction.request, navigationType: navigationAction.navigationType) else {
            decisionHandler(.allow)
            return
        }
        
        decisionHandler(allowed ? .allow : .cancel)
    }
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        webViewDelegate?.webViewDidStartLoad(self)
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webViewDelegate?.webViewDidFinishLoad(self)
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webViewDelegate?.webView(self, didFailLoadWithError: error)
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webViewDelegate?.webView(self, didFailLoadWithError: error)
    }
    
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webViewDelegate?.webViewDidTerminate(self)
    }
    
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust && challenge.previousFailureCount == 0 else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, credential)
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }
    
}

// MARK: - WKUIDelegate
extension KGWKWebView: WKUIDelegate {
    
    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        
        let alert = UIAlertView(title: nil, message: message, delegate: self, cancelButtonTitle: "好的")
        alert.tag = 1000
        alert.show()
        
        alertCompletionHandler = completionHandler
    }
    
    public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        
        let alert = UIAlertView(title: "", message: message, delegate: self, cancelButtonTitle: "取消", otherButtonTitles: "确认")
        alert.tag = 1001
        alert.show()
        
        confirmCompletionHandler = completionHandler
    }
    
    public func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        
        let alert = UIAlertView(title: "", message: prompt, delegate: self, cancelButtonTitle: "取消", otherButtonTitles: "确认")
        alert.alertViewStyle = .plainTextInput
        alert.tag = 1002
        alert.show()

        textCompletionHandler = completionHandler
    }
    
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
}

extension KGWKWebView: UIAlertViewDelegate {
    
    public func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        switch alertView.tag {
        case 1000:
            if let completionHandler = alertCompletionHandler, buttonIndex == alertView.cancelButtonIndex {
                completionHandler()
                alertCompletionHandler = nil
            }
            
        case 1001:
            if let completionHandler = confirmCompletionHandler {
                if buttonIndex == alertView.cancelButtonIndex {
                    completionHandler(false)
                }
                else {
                    completionHandler(true)
                }
                confirmCompletionHandler = nil
            }
            
        case 1002:
            if let completionHandler = textCompletionHandler {
                if buttonIndex == alertView.cancelButtonIndex {
                    completionHandler(nil)
                }
                else {
                    let textField = alertView.textField(at: 0)
                    completionHandler(textField?.text)
                }
                textCompletionHandler = nil
            }
            
        default:
            
            break
        }
    }
    
}

typealias ClosureType =  @convention(c) (Any, Selector, UnsafeRawPointer, Bool, Bool, Any) -> Void

extension KGWKWebView {
    
    var allowDisplayingKeyboardWithoutUserAction: Bool {
        get {
            return false
        } set {
            if newValue == true {
                setKeyboardRequiresUserInteraction()
            }
        }
    }
    
    func setKeyboardRequiresUserInteraction() {
        var selStr = ""
        if #available(iOS 11.3, *) {
            selStr = "X3N0YXJ0QXNzaXN0aW5nTm9kZTp1c2VySXNJbnRlcmFjdGluZzpibHVyUHJldmlvdXNOb2RlOmNoYW5naW5nQWN0aXZpdHlTdGF0ZTp1c2VyT2JqZWN0Og=="
        }
        else {
            selStr = "X3N0YXJ0QXNzaXN0aW5nTm9kZTp1c2VySXNJbnRlcmFjdGluZzpibHVyUHJldmlvdXNOb2RlOnVzZXJPYmplY3Q6Og"
        }
        let sel: Selector = sel_getUid(selStr.kg.base64DecodedString)
        let WKContentView: AnyClass = NSClassFromString("WKContentView")!
        let method = class_getInstanceMethod(WKContentView, sel)
        let originalImp: IMP = method_getImplementation(method!)
        let original: ClosureType = unsafeBitCast(originalImp, to: ClosureType.self)
        let block : @convention(block) (Any, UnsafeRawPointer, Bool, Bool, Any) -> Void = {(me, arg0, arg1, arg2, arg3) in
            original(me, sel, arg0, true, arg2, arg3)
        }
        let imp: IMP = imp_implementationWithBlock(block)
        method_setImplementation(method!, imp)
    }
    
}
