//
//  DouyinLoginSheet.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 9/6/26.
//

import SwiftUI
import WebKit
import AppKit

// MARK: - AppKit 窗口透明化配置器（确保底层 NSWindow 完全透明，透出真液态玻璃效果）
struct SheetBackgroundConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window, "\(type(of: window))".contains("Sheet") {
                window.isOpaque = false
                window.backgroundColor = .clear
                window.hasShadow = true
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

enum LoginSheetMode: Equatable {
    case verifying           // 正在验证登录状态 (220 x 130)
    case success             // 已登录 (190 x 130)
    case error(String)       // 异常提示 (260 x 140)
    case webLogin            // 二维码网页登录卡片 (700 x 466)
}

struct DouyinLoginSheet: View {
    @Binding var isPresented: Bool
    @State private var sheetMode: LoginSheetMode
    @State private var userNickname: String? = nil
    @State private var isLoading = true
    @State private var isDismissing = false
    @State private var showBackButton = false
    @State private var backTrigger = 0
    @State private var closeHovered = false
    @State private var backHovered = false
    @AppStorage("SaveTik_CustomCookie") private var customCookie: String = ""
    
    // 抖音电脑端登录卡片真实尺寸：726 x 483
    // 窗口上下左右深度裁切至 700 x 466，以原生 18pt 圆角彻底遮盖两端圆角不一致造成的空隙与外框线条
    private let sheetWidth: CGFloat = 700
    private let sheetHeight: CGFloat = 466
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        let saved = UserDefaults.standard.string(forKey: "SaveTik_CustomCookie") ?? ""
        if saved.contains("sessionid=") && !saved.isEmpty {
            self._sheetMode = State(initialValue: .verifying)
        } else {
            self._sheetMode = State(initialValue: .webLogin)
        }
        // 严格隔离：初始化时不盲目预载历史昵称，避免切换账号或重新扫码时污染显示
        self._userNickname = State(initialValue: nil)
    }
    
    private var currentSheetWidth: CGFloat {
        switch sheetMode {
        case .verifying: return 220
        case .success: return 190
        case .error: return 260
        case .webLogin: return sheetWidth
        }
    }
    
    private var currentSheetHeight: CGFloat {
        switch sheetMode {
        case .verifying: return 130
        case .success: return 130
        case .error: return 140
        case .webLogin: return sheetHeight
        }
    }
    
    private func dismissSheet() {
        guard !isDismissing else { return }
        isDismissing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isPresented = false
            }
        }
    }
    
    var body: some View {
        ZStack {
            // 0. 底层窗口透明透传
            SheetBackgroundConfigurator()
            
            switch sheetMode {
            case .verifying:
                // 1. 在线实时验证中（紧凑液态玻璃卡片 220 x 130，绝不闪现大号登录卡片）
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.1)
                    Text("正在验证登录状态...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                
                // 右上角提供取消关闭按钮
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            dismissSheet()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.primary.opacity(closeHovered ? 0.12 : 0))
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .glassEffect(.regular, in: .circle)
                        .onHover { closeHovered = $0 }
                        .help("取消")
                    }
                    .padding(.top, 10)
                    .padding(.trailing, 10)
                    Spacer()
                }
                
            case .success:
                // 2. 登录成功紧凑提示弹窗（绿色 checkmark.circle + 已登录 190 x 130，展示 1.2 秒后自动收起弹窗）
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundColor(.green)
                        .symbolEffect(.bounce, value: sheetMode == .success)
                    Text(userNickname != nil ? "已登录 (\(userNickname!))" : "已登录")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        dismissSheet()
                    }
                }
                
            case .error(let message):
                // 3. 验证异常/网络超时提示（260 x 140，展示 2 秒后自动收起）
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.orange)
                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        dismissSheet()
                    }
                }
                
            case .webLogin:
                // 4. 网页登录卡片（700 x 466，仅在未登录或在线验证判定失效后才展示）
                DouyinWebView(
                    isPresented: $isPresented,
                    isSuccess: Binding<Bool>(
                        get: { sheetMode == .success },
                        set: { if $0 {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                sheetMode = .success
                            }
                        }}
                    ),
                    userNickname: $userNickname,
                    isLoading: $isLoading,
                    isDismissing: $isDismissing,
                    showBackButton: $showBackButton,
                    backTrigger: $backTrigger
                )
                .frame(width: sheetWidth, height: sheetHeight)
                .opacity((isLoading || isDismissing || sheetMode == .success) ? 0 : 1)
                .animation(.easeInOut(duration: 0.12), value: isDismissing)
                .animation(.easeInOut(duration: 0.35), value: isLoading)
                
                // 5. 加载状态：macOS 液态玻璃加载中（右键 reload、滑块重载、初次加载时全程平滑呈现）
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("正在加载")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                }
                
                // 6. 顶部对称液态玻璃按钮层（左上角返回 + 右上角关闭）
                VStack {
                    HStack {
                        // 左上角：独立的 Swift 原生液态玻璃圆形返回按钮（仅在身份验证卡片需要返回时展现）
                        if showBackButton && !isLoading {
                            Button {
                                backTrigger += 1
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.primary.opacity(backHovered ? 0.12 : 0))
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.primary.opacity(0.85))
                                }
                                .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Circle())
                            .glassEffect(.regular, in: .circle)
                            .onHover { backHovered = $0 }
                            .help("返回上一步")
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                        }
                        
                        Spacer()
                        
                        // 右上角：独立的 Swift 原生液态玻璃圆形 X 关闭按钮
                        Button {
                            dismissSheet()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.primary.opacity(closeHovered ? 0.12 : 0))
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.primary.opacity(0.85))
                            }
                            .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .glassEffect(.regular, in: .circle)
                        .onHover { closeHovered = $0 }
                        .help("退出登录")
                    }
                    .padding(.top, 14)
                    .padding(.horizontal, 14)
                    
                    Spacer()
                }
            }
        }
        .frame(
            width: currentSheetWidth,
            height: currentSheetHeight
        )
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 8)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: sheetMode)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showBackButton)
        .presentationBackground(.clear)
        .onAppear {
            if sheetMode == .verifying {
                Task {
                    let status = await DouyinService.shared.verifySessionValidity(cookieString: customCookie)
                    await MainActor.run {
                        guard !isDismissing && isPresented else { return }
                        switch status {
                        case .valid(let nickname):
                            let cleanNick = (nickname != nil && nickname != "抖音用户" && !nickname!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? nickname : nil
                            self.userNickname = cleanNick
                            if let nick = cleanNick {
                                UserDefaults.standard.set(nick, forKey: "SaveTik_UserNickname")
                            } else {
                                UserDefaults.standard.removeObject(forKey: "SaveTik_UserNickname")
                            }
                            UserDefaults.standard.synchronize()
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                self.sheetMode = .success
                            }
                        case .invalid(let reason):
                            print("⚠️ [DouyinLoginSheet] 登录凭证已失效 (\(reason))，自动清除并展开扫码登录卡片")
                            DouyinService.clearAllAuthCookies()
                            self.customCookie = ""
                            self.userNickname = nil
                            self.isLoading = true
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                                self.sheetMode = .webLogin
                            }
                        case .networkError(let errorMsg):
                            print("⚠️ [DouyinLoginSheet] 在线验证网络异常: \(errorMsg)")
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                self.sheetMode = .error("网络连接异常，无法确认登录状态")
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: isPresented) { newValue in
            if !newValue {
                isDismissing = true
            }
        }
        .onChange(of: sheetMode) { newMode in
            if newMode == .success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismissSheet()
                }
            } else if case .error = newMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    dismissSheet()
                }
            }
        }
    }
}

// MARK: - NSViewRepresentable for WKWebView
// MARK: - 弱引用脚本消息处理器代理（防止 WKUserContentController 强引用 Coordinator 造成循环引用）
private class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

// MARK: - NSViewRepresentable for WKWebView
struct DouyinWebView: NSViewRepresentable {
    @Binding var isPresented: Bool
    @Binding var isSuccess: Bool
    @Binding var userNickname: String?
    @Binding var isLoading: Bool
    @Binding var isDismissing: Bool
    @Binding var showBackButton: Bool
    @Binding var backTrigger: Int
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver, WKScriptMessageHandler {
        var parent: DouyinWebView
        var pollingTimer: Timer?
        var cardCheckTimer: Timer?
        var captchaRecoveryTimer: Timer?
        var isLoginCardDisplayed = false
        var isCaptchaActive = false
        var hasSucceeded = false
        var isVerifyingSession = false
        var lastVerifiedCookieString: String = ""
        var lastHandledBackTrigger = 0
        var networkRetryCount = 0
        weak var webView: WKWebView?
        
        init(_ parent: DouyinWebView) {
            self.parent = parent
            super.init()
        }
        
        // 响应来自网页内 JS 探针的登录事件与返回按钮状态通知
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "savetikLogin", let webView = webView {
                self.lastVerifiedCookieString = "" // 强制清除缓存，立即允许触发新一轮在线鉴权
                checkCookies(in: webView.configuration.websiteDataStore.httpCookieStore)
            } else if message.name == "savetikBackState" {
                if let canBack = message.body as? Bool {
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            self.parent.showBackButton = canBack
                        }
                    }
                }
            } else if message.name == "savetikCaptchaSuccess" {
                handleCaptchaSuccess()
            }
        }
        
        // 响应网页端滑动验证码成功（解决滑动成功后卡在验证码加载页问题）
        func handleCaptchaSuccess() {
            guard !hasSucceeded else { return }
            
            // 关键保护：若真实登录卡片或二次身份验证已在呈现中，绝不可重新加载页面！
            guard !isLoginCardDisplayed else {
                print("ℹ️ [DouyinLoginSheet] 登录卡片/身份验证流程正在进行中，忽略滑块通知")
                return
            }
            
            print("🧩 [DouyinLoginSheet] 收到初次加载滑动验证码完成通知，等待网络校验与凭证入库...")
            
            // 取消旧的恢复定时器（如果有）
            captchaRecoveryTimer?.invalidate()
            
            // 确保卡片探测积极运行中
            if let wv = self.webView {
                self.startCardDetection(in: wv)
            }
            
            // 启动安全恢复延迟任务：给服务端 2.5 秒完成轨迹校验与 Cookie 写入
            // 关键准则：若验证码容器仍然存在且活跃（用户可能正在交互或重试），绝对不可重载页面！
            // 只有当验证码容器确已关闭销毁，但 2.5 秒内未自动弹出登录卡片时，才认定卡在空白等待页，此时安全重载登录 URL
            captchaRecoveryTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
                guard let self = self, let webView = self.webView, !self.hasSucceeded else { return }
                guard !self.isLoginCardDisplayed else { return }
                
                webView.evaluateJavaScript("""
                (function() {
                    // 1. 是否处于二次身份验证
                    let mfa = document.querySelector('div[class*="second_verify"], div[class*="second-verify"], [class*="second_verify"], [class*="second-verify"], div[class*="passport-modal"], div[class*="verify_mask"], div[class*="verify-mask"]');
                    if (mfa || window.__savetik_in_mfa) return "mfa";
                    
                    // 2. 是否已显示登录卡片
                    let card = document.querySelector('.douyin_login_new_class') ||
                               document.querySelector('#douyin-login-new-id') ||
                               document.querySelector('article') ||
                               document.querySelector('.semi-modal-content');
                    if (card) {
                        let r = card.getBoundingClientRect();
                        if (r.width >= 300 && r.height >= 220) return "card";
                    }
                    
                    // 3. 关键安全保障：验证码容器是否仍然存在且可见（若仍在界面呈现，说明用户正在操作或重试，绝不可重载）
                    let captcha = document.querySelector('#captcha_container') ||
                                  document.querySelector('.secsdk_captcha_modal') ||
                                  document.querySelector('div[class*="secsdk"]') ||
                                  document.querySelector('iframe[src*="captcha"]');
                    if (captcha && !captcha.hasAttribute('data-savetik-captcha-hidden')) {
                        let r = captcha.getBoundingClientRect();
                        let st = window.getComputedStyle(captcha);
                        if (r.width >= 120 && r.height >= 80 && st.display !== 'none' && st.visibility !== 'hidden') {
                            return "captcha_active";
                        }
                    }
                    
                    return "stuck";
                })();
                """) { [weak self] res, _ in
                    guard let self = self, let webView = self.webView, !self.hasSucceeded, !self.isLoginCardDisplayed else { return }
                    let state = (res as? String) ?? "stuck"
                    if state == "card" || state == "mfa" {
                        print("🎉 [DouyinLoginSheet] 登录卡片/二步验证已就绪，无需刷新...")
                        self.isLoginCardDisplayed = true
                        self.startCardDetection(in: webView)
                    } else if state == "captcha_active" {
                        print("ℹ️ [DouyinLoginSheet] 验证码容器仍在界面呈现中，取消重载，保持用户交互...")
                        self.startCardDetection(in: webView)
                    } else {
                        print("🔄 [DouyinLoginSheet] 验证码已通过且容器已关闭，但卡在空白等待页，安全凭据已入库，重新载入登录卡片 URL...")
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                self.parent.isLoading = true
                            }
                        }
                        if let loginUrl = URL(string: "https://www.douyin.com/?modal_id=login_douyin") {
                            webView.load(URLRequest(url: loginUrl))
                            self.startCardDetection(in: webView)
                        }
                    }
                }
            }
        }
        
        // 执行网页端返回逻辑
        func triggerBack() {
            let js = """
            (function() {
                window.__savetik_back_clicked = true;
                let back = window.__savetik_back_target;
                if (!back || !document.body.contains(back)) {
                    back = document.querySelector('.back-ZqcRC8, div[class*="back-"], [class*="back-"], .semi-modal-back, [class*="modal-back"], [class*="back-btn"], [aria-label*="back" i], [aria-label*="return" i]');
                }
                if (back) {
                    ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach(function(type) {
                        let evt = new MouseEvent(type, { bubbles: true, cancelable: true, view: window });
                        back.dispatchEvent(evt);
                    });
                    if (typeof back.click === 'function') {
                        back.click();
                    }
                } else if (window.history.length > 1) {
                    window.history.back();
                }
            })();
            """
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
        
        // 启动 .common 模式高频轮询（350ms，不受鼠标移动或模态追踪阻断）
        func startPollingTimer(in cookieStore: WKHTTPCookieStore, webView: WKWebView) {
            pollingTimer?.invalidate()
            let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self, weak cookieStore, weak webView] _ in
                guard let self = self, let cookieStore = cookieStore, !self.hasSucceeded else { return }
                self.checkCookies(in: cookieStore)
                if let wv = webView {
                    self.injectImmersiveStyles(into: wv)
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.pollingTimer = timer
        }
        
        // 注入沉浸式去噪 CSS 与 JS 探针
        func injectImmersiveStyles(into webView: WKWebView) {
            let css = """
            html, body {
                background: transparent !important;
                overflow: hidden !important;
                margin: 0 !important;
                padding: 0 !important;
                width: 100vw !important;
                height: 100vh !important;
            }
            #dark,
            #light,
            #douyin-navigation,
            div[id*="navigation"],
            div[class*="navigation"],
            nav,
            aside,
            div[role="navigation"],
            #douyin-right-container,
            div[id*="right-container"],
            div[class*="right-container"],
            #douyin-header,
            header,
            #douyin-sidebar,
            div[id*="sidebar"],
            div[class*="sidebar"],
            [data-e2e="feed-active-video"],
            div[class*="video-player"],
            div[class*="video"],
            div[class*="feed"],
            #slidelist,
            #slidelist div[class*="slide"],
            #slidelist div[id*="slide"],
            div[class*="recommend"],
            div[class*="player"],
            #slidelist div[class*="loading"],
            #slidelist div[class*="spinner"],
            #slidelist div[class*="loader"],
            div[class*="feed"] div[class*="loading"],
            div[class*="feed"] div[class*="spinner"],
            div[class*="feed"] div[class*="loader"] {
                display: none !important;
                opacity: 0 !important;
                visibility: hidden !important;
                pointer-events: none !important;
            }
            .semi-modal-mask,
            div[class*="second_verify_mask"], [class*="second_verify_mask"],
            .secsdk_captcha_mask, [class*="captcha_mask"], [class*="captcha-mask"], [id*="captcha_mask"] {
                background: transparent !important;
            }
            .semi-modal-wrap, div[class*="modal-wrap"] {
                background: transparent !important;
                position: fixed !important;
                inset: 0 !important;
                width: 100vw !important;
                height: 100vh !important;
                display: flex !important;
                align-items: center !important;
                justify-content: center !important;
                padding: 0 !important;
                margin: 0 !important;
            }
            .semi-modal, div[class*="semi-modal-content"], .douyin_login_new_class, #douyin-login-new-id {
                box-shadow: none !important;
                margin: 0 !important;
                border: none !important;
            }
            [id*="login-full-panel"],
            #login-panel-new,
            .douyin_login_new_class,
            #douyin-login-new-id,
            .semi-modal-wrap,
            .semi-modal,
            [class*="second_verify"],
            [class*="second-verify"],
            #captcha_container,
            [class*="secsdk_captcha"],
            [class*="captcha_verify"] {
                opacity: 1 !important;
                pointer-events: auto !important;
            }
            /* 当存在二次身份验证卡片时，仅精准隐藏底层原始主登录卡片中的二维码与切换区域，绝不误伤二次验证卡片及其具体验证方式 */
            body:has([class*="second_verify"]) .douyin_login_new_class .UXzkscqE,
            body:has([class*="second_verify"]) .douyin_login_new_class .zzs0DGQV,
            body:has([class*="second_verify"]) .douyin_login_new_class .RyOwPUDZ,
            body:has([class*="second_verify"]) .douyin_login_new_class .hnHfmHGH,
            body:has([class*="second-verify"]) .douyin_login_new_class .UXzkscqE,
            body:has([class*="second-verify"]) .douyin_login_new_class .zzs0DGQV,
            body:has([class*="second-verify"]) .douyin_login_new_class .RyOwPUDZ,
            body:has([class*="second-verify"]) .douyin_login_new_class .hnHfmHGH,
            body:has([class*="verify_mask"]) .douyin_login_new_class .UXzkscqE,
            body:has([class*="verify_mask"]) .douyin_login_new_class .zzs0DGQV,
            body:has([class*="verify_mask"]) .douyin_login_new_class .RyOwPUDZ,
            body:has([class*="verify_mask"]) .douyin_login_new_class .hnHfmHGH,
            body:has([class*="passport-modal"]) .douyin_login_new_class .UXzkscqE,
            body:has([class*="passport-modal"]) .douyin_login_new_class .zzs0DGQV,
            body:has([class*="passport-modal"]) .douyin_login_new_class .RyOwPUDZ,
            body:has([class*="passport-modal"]) .douyin_login_new_class .hnHfmHGH {
                display: none !important;
                opacity: 0 !important;
                visibility: hidden !important;
                pointer-events: none !important;
            }
            /* 强力保障二次身份验证、安全验证及各具体验证组件（短信输入、按钮、二次二维码、画布等）完全正常呈现 */
            [class*="second_verify"],
            [class*="second-verify"],
            [class*="verify_mask"],
            [class*="passport-modal"],
            div[class*="second_verify"] *,
            div[class*="second-verify"] *,
            div[class*="verify"] *,
            div[class*="passport"] * {
                opacity: 1 !important;
                visibility: visible !important;
                pointer-events: auto !important;
            }
            /* 确保二次扫码中的二维码完全呈现 */
            div[class*="second_verify"] [class*="qrcode"],
            div[class*="second-verify"] [class*="qrcode"],
            div[class*="verify"] [class*="qrcode"],
            div[class*="passport"] [class*="qrcode"],
            div[class*="second_verify"] img,
            div[class*="second-verify"] img,
            div[class*="second_verify"] canvas,
            div[class*="second-verify"] canvas {
                display: block !important;
                opacity: 1 !important;
                visibility: visible !important;
                pointer-events: auto !important;
            }
            /* 保障滑动验证码（滑块、滑道、拼图碎块、背景底图及容器）正常置顶与交互，且不阻止验证完成后自然淡出与销毁 */
            #captcha_container,
            .secsdk_captcha_modal,
            [class*="secsdk_captcha_modal"],
            [class*="captcha_verify_container"],
            iframe[src*="captcha"],
            iframe[src*="verify"],
            #nocaptcha-container {
                z-index: 999999 !important;
                pointer-events: auto;
            }
            [data-savetik-captcha-hidden="true"],
            [data-savetik-captcha-hidden="true"] * {
                display: none !important;
                opacity: 0 !important;
                visibility: hidden !important;
                pointer-events: none !important;
            }
            /* 彻底隐藏网页弹窗卡片自带的右上角关闭叉号与左上角返回箭头，使原生渐变与底色完全无缝呈现（零色块方案） */
            .semi-modal-close,
            [class*="modal-close"],
            [class*="close-btn"],
            [class*="closeIcon"],
            [class*="close-icon"],
            [aria-label="Close"],
            [aria-label="close"],
            .close-gz62ZZ,
            div[class*="close-"],
            [class*="close-"],
            .YoNA2Hyj,
            .qKr0RhiL,
            .semi-modal-back,
            [class*="modal-back"],
            [class*="back-btn"],
            [class*="backIcon"],
            [class*="back-icon"],
            .back-ZqcRC8,
            div[class*="back-"],
            [class*="back-"],
            [aria-label="Back"],
            [aria-label="back"],
            [aria-label="Return"] {
                opacity: 0 !important;
                visibility: hidden !important;
                pointer-events: none !important;
            }
            """
            
            let js = """
            (function() {
                let existing = document.getElementById('savetik-immersive-style');
                if (!existing) {
                    let style = document.createElement('style');
                    style.id = 'savetik-immersive-style';
                    style.innerHTML = `\(css)`;
                    if (document.head) {
                        document.head.appendChild(style);
                    } else if (document.documentElement) {
                        document.documentElement.appendChild(style);
                    }
                }
                
                // 动态遍历并精准隐藏卡片右上角关闭按钮与左上角返回按钮
                function processWebButtons() {
                    // 0. 当出现二次身份验证卡片时，精准保全二次验证与后续具体方式的视图层级
                    let mfa = document.querySelector('div[class*="second_verify"], div[class*="second-verify"], [class*="second_verify"], [class*="second-verify"], div[class*="passport-modal"], div[class*="verify_mask"], div[class*="verify-mask"], div[class*="verify_container"], div[class*="verify-container"], div[class*="verify_box"], div[class*="verify-box"]') ||
                              (function() {
                                  let modals = document.querySelectorAll('.semi-modal, div[role="dialog"], div[class*="modal"]');
                                  for (let m of modals) {
                                      let text = m.innerText || '';
                                      if (text.includes('身份验证') || text.includes('安全验证') || text.includes('验证码') || text.includes('短信') || text.includes('扫码') || text.includes('刷脸')) {
                                          if (!m.classList.contains('douyin_login_new_class') && m.id !== 'douyin-login-new-id') {
                                              return m;
                                          }
                                      }
                                  }
                                  return null;
                              })();
                    if (mfa) {
                        window.__savetik_in_mfa = true;
                        // 精准隐藏底层主登录卡片的二维码与切换区域，绝不误伤二次验证自身任何层级及具体方式（短信/扫码/刷脸）
                        let qrBoxes = document.querySelectorAll('.douyin_login_new_class div[class*="qrcode"], .douyin_login_new_class .UXzkscqE, .douyin_login_new_class .zzs0DGQV, .douyin_login_new_class .RyOwPUDZ, .douyin_login_new_class .hnHfmHGH');
                        qrBoxes.forEach(function(qr) {
                            if (!qr.contains(mfa) && qr !== mfa) {
                                qr.setAttribute('data-savetik-mfa-hidden', 'true');
                                qr.style.setProperty('display', 'none', 'important');
                                qr.style.setProperty('opacity', '0', 'important');
                                qr.style.setProperty('visibility', 'hidden', 'important');
                                qr.style.setProperty('pointer-events', 'none', 'important');
                            }
                        });
                    } else if (window.__savetik_in_mfa) {
                        if (window.__savetik_back_clicked) {
                            // 仅当用户主动点击原生“返回”按钮时，才恢复底层登录卡片
                            window.__savetik_back_clicked = false;
                            window.__savetik_in_mfa = false;
                            document.querySelectorAll('[data-savetik-mfa-hidden="true"]').forEach(function(el) {
                                el.removeAttribute('data-savetik-mfa-hidden');
                                el.style.removeProperty('display');
                                el.style.removeProperty('opacity');
                                el.style.removeProperty('visibility');
                                el.style.removeProperty('pointer-events');
                            });
                        }
                    }
                    
                    // 1. 关闭按钮静默隐藏（包括常规登录卡片与 MFA 身份验证卡片）
                    let closeSelectors = [
                        '.close-gz62ZZ', 'div[class*="close-"]', '[class*="close-"]',
                        '.YoNA2Hyj', '.qKr0RhiL',
                        '.semi-modal-close', '[class*="modal-close"]', '[class*="close-btn"]',
                        '[class*="closeIcon"]', '[class*="close-icon"]',
                        '[aria-label="Close"]', '[aria-label="close"]'
                    ];
                    let closeElements = document.querySelectorAll(closeSelectors.join(','));
                    closeElements.forEach(function(el) {
                        el.style.setProperty('opacity', '0', 'important');
                        el.style.setProperty('visibility', 'hidden', 'important');
                        el.style.setProperty('pointer-events', 'none', 'important');
                    });
                    
                    // 2. 返回按钮精准探测与静默隐藏
                    let backSelectors = [
                        '.back-ZqcRC8', 'div[class*="back-"]', '[class*="back-"]',
                        '.semi-modal-back', '[class*="modal-back"]', '[class*="back-btn"]',
                        '[class*="backIcon"]', '[class*="back-icon"]',
                        '[aria-label="Back"]', '[aria-label="back"]', '[aria-label="Return"]'
                    ];
                    let backElements = document.querySelectorAll(backSelectors.join(','));
                    let hasBack = false;
                    backElements.forEach(function(el) {
                        el.style.setProperty('opacity', '0', 'important');
                        el.style.setProperty('visibility', 'hidden', 'important');
                        el.style.setProperty('pointer-events', 'none', 'important');
                        
                        // 判断是否为有效挂载且处于当前视口中的返回按钮
                        let r = el.getBoundingClientRect();
                        if (r.width > 0 && r.height > 0 && r.bottom > 0 && r.top < window.innerHeight) {
                            hasBack = true;
                            window.__savetik_back_target = el;
                        }
                    });
                    
                    // 3. 兜底坐标扫描（针对卡片右上角和左上角其他可能动态生成的按钮）
                    let card = document.querySelector('.douyin_login_new_class') ||
                               document.querySelector('#douyin-login-new-id') ||
                               document.querySelector('.semi-modal') ||
                               document.querySelector('div[class*="second_verify"]') ||
                               document.querySelector('div[class*="passport"]') ||
                               document.querySelector('article');
                    if (card) {
                        let cardCls = (card.className && typeof card.className === 'string') ? card.className.toLowerCase() : '';
                        let cardId = (card.id || '').toLowerCase();
                        if (cardCls.includes('captcha') || cardCls.includes('secsdk') || cardId.includes('captcha') || cardId.includes('secsdk')) {
                            card = null;
                        }
                    }
                    if (card) {
                        let cardRect = card.getBoundingClientRect();
                        if (cardRect.width >= 100 && cardRect.height >= 100) {
                            card.querySelectorAll('button, svg, div, a').forEach(function(el) {
                                let r = el.getBoundingClientRect();
                                if (r.width > 0 && r.width <= 56 && r.height > 0 && r.height <= 56) {
                                    let cls = (el.className && typeof el.className === 'string') ? el.className.toLowerCase() : '';
                                    let aria = (el.getAttribute('aria-label') || '').toLowerCase();
                                    
                                    // 右上角关闭区域
                                    if (r.right >= cardRect.right - 90 && r.top <= cardRect.top + 70) {
                                        if (cls.includes('close') || aria.includes('close') || el.tagName.toLowerCase() === 'svg' || el.tagName.toLowerCase() === 'button') {
                                            el.style.setProperty('opacity', '0', 'important');
                                            el.style.setProperty('visibility', 'hidden', 'important');
                                            el.style.setProperty('pointer-events', 'none', 'important');
                                        }
                                    }
                                    // 左上角返回区域
                                    if (r.left <= cardRect.left + 90 && r.top <= cardRect.top + 70) {
                                        if (cls.includes('back') || cls.includes('arrow') || cls.includes('return') || aria.includes('back') || aria.includes('return')) {
                                            hasBack = true;
                                            window.__savetik_back_target = el;
                                            el.style.setProperty('opacity', '0', 'important');
                                            el.style.setProperty('visibility', 'hidden', 'important');
                                            el.style.setProperty('pointer-events', 'none', 'important');
                                        }
                                    }
                                }
                            });
                        }
                    }
                    
                    try {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.savetikBackState) {
                            window.webkit.messageHandlers.savetikBackState.postMessage(hasBack);
                        }
                    } catch(e) {}
                }
                processWebButtons();
                
                function triggerCaptchaSuccess() {
                    if (window.__savetik_card_displayed || window.__savetik_in_mfa) return;
                    if (!window.__savetik_user_dragged) return;
                    if (window.__savetik_captcha_success_fired) return;
                    window.__savetik_captcha_success_fired = true;
                    try {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.savetikCaptchaSuccess) {
                            window.webkit.messageHandlers.savetikCaptchaSuccess.postMessage('success');
                        }
                    } catch(e) {}
                }
                
                if (!window.__savetik_msg_listener) {
                    window.__savetik_msg_listener = true;
                    window.addEventListener('message', function(e) {
                        try {
                            if (window.__savetik_card_displayed || window.__savetik_in_mfa) return;
                            if (!window.__savetik_user_dragged) return;
                            let d = e.data;
                            let str = typeof d === 'string' ? d : JSON.stringify(d);
                            if (str && !str.includes('second_verify') && !str.includes('second-verify') && !str.includes('passport')) {
                                let sLower = str.toLowerCase();
                                if (sLower.includes('"init"') || sLower.includes('"ready"') || sLower.includes('"resize"') || sLower.includes('"reset"')) {
                                    return;
                                }
                                let isSuccess = sLower.includes('validate_success') ||
                                                sLower.includes('"status":"success"') ||
                                                sLower.includes('"action":"success"') ||
                                                sLower.includes('"event":"success"') ||
                                                sLower.includes('"result":"success"');
                                if ((sLower.includes('secsdk') || sLower.includes('captcha')) && isSuccess) {
                                    triggerCaptchaSuccess();
                                }
                            }
                        } catch(err) {}
                    });
                }
                
                if (!window.__savetik_observer) {
                    window.__savetik_observer = new MutationObserver(function() {
                        processWebButtons();
                        
                        // 监测登录状态与验证码完成变化
                        try {
                            let text = (document.body ? document.body.innerText : '') || '';
                            if (!window.__savetik_card_displayed && !window.__savetik_in_mfa) {
                                if (!text.includes('选择验证方式') && !text.includes('身份验证') && !text.includes('安全验证')) {
                                    if (window.__savetik_user_dragged && (text.includes('滑动成功') || text.includes('拼图成功') || text.includes('验证通过'))) {
                                        triggerCaptchaSuccess();
                                    }
                                }
                            }
                            if (text.includes('登录成功') || text.includes('扫码成功') || text.includes('验证成功')) {
                                window.webkit.messageHandlers.savetikLogin.postMessage('state_change');
                            }
                        } catch(e) {}
                    });
                    let target = document.body || document.documentElement;
                    if (target) {
                        window.__savetik_observer.observe(target, { childList: true, subtree: true });
                    }
                }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        
        // 导航决策：捕获重定向与跳转离开登录弹窗的时机
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            
            let scheme = url.scheme?.lowercased() ?? ""
            guard scheme == "http" || scheme == "https" || scheme == "about" else {
                decisionHandler(.cancel)
                return
            }
            
            // 当发生跳转时立即检测凭证
            checkCookies(in: webView.configuration.websiteDataStore.httpCookieStore)
            
            // 若已捕获成功，直接阻止后续导航以防加载首页视频
            if hasSucceeded {
                decisionHandler(.cancel)
                return
            }
            
            // 关键：仅在已就绪展示后（!parent.isLoading）主框架（isMainFrame）发生重定向离开登录授权体系时进行拦截
            if !parent.isLoading, navigationAction.targetFrame?.isMainFrame == true, let host = url.host?.lowercased(), host.contains("douyin.com") {
                let urlStr = url.absoluteString
                let isLoginOrAuth = urlStr.contains("modal_id=login_douyin") ||
                                    urlStr.contains("captcha") ||
                                    urlStr.contains("verify") ||
                                    urlStr.contains("second") ||
                                    urlStr.contains("passport") ||
                                    urlStr.contains("auth") ||
                                    urlStr.contains("security") ||
                                    urlStr.contains("safe") ||
                                    urlStr.contains("sec") ||
                                    urlStr.contains("login") ||
                                    urlStr.contains("account") ||
                                    urlStr.contains("identity") ||
                                    urlStr.contains("challenge") ||
                                    urlStr.contains("sms") ||
                                    urlStr.contains("phone") ||
                                    urlStr.contains("code") ||
                                    urlStr.contains("falcon")
                if !isLoginOrAuth {
                    decisionHandler(.cancel)
                    self.lastVerifiedCookieString = ""
                    
                    let store = webView.configuration.websiteDataStore.httpCookieStore
                    store.getAllCookies { [weak self, weak webView] cookies in
                        guard let self = self, let webView = webView else { return }
                        let douyinCookies = cookies.filter { $0.domain.contains("douyin.com") }
                        let hasSession = douyinCookies.contains { cookie in
                            let name = cookie.name.lowercased()
                            let val = cookie.value.trimmingCharacters(in: .whitespacesAndNewlines)
                            return (name == "sessionid" || name == "sessionid_ss") && !val.isEmpty
                        }
                        
                        if hasSession {
                            // 已登录：校验会话并呈现登录成功
                            self.checkCookies(in: store)
                        } else {
                            // 未登录：首先检查页面是否处于二次身份验证流程中，若是则绝对不可重载登录卡片
                            webView.evaluateJavaScript("""
                            (function() {
                                return !!(window.__savetik_in_mfa || document.querySelector('div[class*="second_verify"], div[class*="second-verify"], [class*="second_verify"], [class*="second-verify"], div[class*="passport-modal"], div[class*="verify_mask"], div[class*="verify-mask"], div[class*="verify_container"], div[class*="verify-container"], div[class*="verify_box"], div[class*="verify-box"]'));
                            })()
                            """) { [weak self, weak webView] res, _ in
                                guard let self = self, let webView = webView, !self.hasSucceeded else { return }
                                let inMfa = (res as? Bool) == true
                                if inMfa {
                                    print("ℹ️ [DouyinLoginSheet] 当前正在进行二次身份验证，保持界面绝不重载")
                                    return
                                }
                                
                                // 仅在明确不是二次验证、且确实已脱离登录授权流程时，才重新加载登录卡片
                                print("ℹ️ [DouyinLoginSheet] 检测到离开登录授权流程，重新加载登录卡片...")
                                DispatchQueue.main.async {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        self.parent.isLoading = true
                                    }
                                    if let loginUrl = URL(string: "https://www.douyin.com/?modal_id=login_douyin") {
                                        webView.load(URLRequest(url: loginUrl))
                                        self.startCardDetection(in: webView)
                                    }
                                }
                            }
                        }
                    }
                    return
                }
            }
            
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
        
        // 智能探针：精准检测登录卡片、滑块验证码或二次身份验证卡片就绪状态
        func startCardDetection(in webView: WKWebView) {
            cardCheckTimer?.invalidate()
            var attempts = 0
            let maxAttempts = 100 // 100 * 0.2s = 20 秒超时兜底，保障网络波动与冷启动安全
            
            cardCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self, weak webView] t in
                guard let self = self, let webView = webView else {
                    t.invalidate()
                    return
                }
                attempts += 1
                
                let js = """
                (function() {
                    // 1. 登录卡片
                    let card = document.querySelector('.douyin_login_new_class') ||
                               document.querySelector('#douyin-login-new-id') ||
                               document.querySelector('article') ||
                               document.querySelector('.semi-modal-content');
                    if (card) {
                        let r = card.getBoundingClientRect();
                        if (r.width >= 300 && r.height >= 220) {
                            return "card";
                        }
                    }
                    // 2. MFA 身份安全验证卡片
                    let verify = document.querySelector('div[class*="second_verify"]') ||
                                 document.querySelector('div[class*="second-verify"]') ||
                                 document.querySelector('div[class*="passport-modal"]') ||
                                 document.querySelector('.semi-modal');
                    if (verify) {
                        let r = verify.getBoundingClientRect();
                        if (r.width >= 280 && r.height >= 200) {
                            return "mfa";
                        }
                    }
                    // 3. 滑动验证码容器（出现时必须让用户交互）
                    let captcha = document.querySelector('#captcha_container') ||
                                  document.querySelector('div[id*="captcha"]') ||
                                  document.querySelector('div[class*="captcha"]') ||
                                  document.querySelector('.secsdk_captcha_modal') ||
                                  document.querySelector('div[class*="secsdk"]') ||
                                  document.querySelector('div[id*="secsdk"]') ||
                                  document.querySelector('iframe[src*="captcha"]') ||
                                  document.querySelector('iframe[src*="verify"]') ||
                                  document.querySelector('div[class*="verify_slide"]') ||
                                  document.querySelector('div[class*="slide_verify"]');
                    if (captcha) {
                        let isHidden = captcha.hasAttribute('data-savetik-captcha-hidden');
                        if (!isHidden) {
                            let r = captcha.getBoundingClientRect();
                            if (r.width >= 120 && r.height >= 80) {
                                return "captcha";
                            }
                        }
                    }
                    return "none";
                })();
                """
                webView.evaluateJavaScript(js) { [weak self, weak webView] res, _ in
                    guard let self = self, let webView = webView, self.cardCheckTimer != nil else { return }
                    let state = (res as? String) ?? "none"
                    if state == "card" || state == "mfa" {
                        t.invalidate()
                        self.cardCheckTimer = nil
                        self.isLoginCardDisplayed = true
                        self.isCaptchaActive = false
                        self.captchaRecoveryTimer?.invalidate()
                        self.captchaRecoveryTimer = nil
                        
                        // 确保沉浸式去噪样式全部就位
                        self.injectImmersiveStyles(into: webView)
                        
                        // 标记卡片已真实为用户可见呈现并隐藏可能残存的旧验证码容器
                        webView.evaluateJavaScript("""
                        (function() {
                            window.__savetik_card_displayed = true;
                            let captchas = document.querySelectorAll('#captcha_container, .secsdk_captcha_modal, [class*="secsdk_captcha_modal"], [class*="captcha_verify_container"]');
                            captchas.forEach(function(c) {
                                c.setAttribute('data-savetik-captcha-hidden', 'true');
                                c.style.setProperty('display', 'none', 'important');
                            });
                        })();
                        """, completionHandler: nil)
                        
                        // 目标容器已准确就绪，平滑淡入展示
                        DispatchQueue.main.async {
                            webView.alphaValue = 1.0
                            withAnimation(.easeInOut(duration: 0.35)) {
                                self.parent.isLoading = false
                            }
                        }
                    } else if state == "captcha" {
                        // 发现滑动验证码！必须展示给用户滑动，但不能停止探针，因为验证完后还需要检测卡片出现
                        self.isCaptchaActive = true
                        self.isLoginCardDisplayed = false
                        self.injectImmersiveStyles(into: webView)
                        
                        DispatchQueue.main.async {
                            webView.alphaValue = 1.0
                            withAnimation(.easeInOut(duration: 0.35)) {
                                self.parent.isLoading = false
                            }
                        }
                    } else if attempts >= maxAttempts {
                        t.invalidate()
                        self.cardCheckTimer = nil
                        
                        // 超时兜底呈现，绝不永久卡死在加载态
                        self.injectImmersiveStyles(into: webView)
                        DispatchQueue.main.async {
                            webView.alphaValue = 1.0
                            withAnimation(.easeInOut(duration: 0.35)) {
                                self.parent.isLoading = false
                            }
                        }
                    }
                }
            }
        }
        
        // 用户右键 Reload、滑块验证后重载或初次开始加载时，立即切换为液态玻璃“正在加载”，绝不漏出抖音主页
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoginCardDisplayed = false
            isCaptchaActive = false
            captchaRecoveryTimer?.invalidate()
            captchaRecoveryTimer = nil
            
            DispatchQueue.main.async {
                webView.alphaValue = 1.0
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.parent.isLoading = true
                    self.parent.showBackButton = false
                }
            }
            webView.evaluateJavaScript("""
            window.__savetik_captcha_success_fired = false;
            window.__savetik_captcha_success_reported = false;
            window.__savetik_user_dragged = false;
            window.__savetik_is_pointer_down = false;
            document.querySelectorAll('[data-savetik-captcha-hidden]').forEach(function(c) {
                c.removeAttribute('data-savetik-captcha-hidden');
                c.style.removeProperty('display');
            });
            """, completionHandler: nil)
            startCardDetection(in: webView)
            checkCookies(in: webView.configuration.websiteDataStore.httpCookieStore)
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            injectImmersiveStyles(into: webView)
            startCardDetection(in: webView)
            checkCookies(in: webView.configuration.websiteDataStore.httpCookieStore)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectImmersiveStyles(into: webView)
            startCardDetection(in: webView)
            checkCookies(in: webView.configuration.websiteDataStore.httpCookieStore)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            checkCookies(in: cookieStore)
        }
        
        // 完成真实登录凭据收敛、持久化及界面过渡
        func completeLogin(cookieString: String, cookieMap: [String: String], nickname: String?) {
            guard !hasSucceeded else { return }
            hasSucceeded = true
            
            // 立即停止所有轮询与探针
            pollingTimer?.invalidate()
            pollingTimer = nil
            cardCheckTimer?.invalidate()
            cardCheckTimer = nil
            captchaRecoveryTimer?.invalidate()
            captchaRecoveryTimer = nil
            
            let cleanNick = (nickname != nil && nickname != "抖音用户" && !nickname!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? nickname : nil
            print("✅ [DouyinLoginSheet] 在线验证通过，用户真实登录成功: \(cleanNick ?? "已登录")，有效 Cookie 项数: \(cookieMap.count)")
            if let sess = cookieMap["sessionid"] ?? cookieMap["sessionid_ss"] {
                print("🔑 [DouyinLoginSheet] 获得真实 sessionid 凭证: \(sess.prefix(10))...")
            }
            
            // 写入持久化存储并通知数据服务刷新
            UserDefaults.standard.set(cookieString, forKey: "SaveTik_CustomCookie")
            if let nick = cleanNick {
                UserDefaults.standard.set(nick, forKey: "SaveTik_UserNickname")
            } else {
                UserDefaults.standard.removeObject(forKey: "SaveTik_UserNickname")
            }
            UserDefaults.standard.synchronize()
            DouyinService.shared.clearCachedCredentials()
            
            // 彻底终止 WebKit 跳转并清空页面，保持透明
            webView?.alphaValue = 0
            webView?.stopLoading()
            webView?.loadHTMLString("", baseURL: nil)
            
            parent.userNickname = cleanNick
            
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                parent.isSuccess = true
            }
        }
        
        // 核心：严格校验核心鉴权凭据 sessionid / sessionid_ss 并发起在线验证
        func checkCookies(in cookieStore: WKHTTPCookieStore) {
            guard !hasSucceeded, !isVerifyingSession else { return }
            
            cookieStore.getAllCookies { [weak self] cookies in
                guard let self = self, !self.hasSucceeded, !self.isVerifyingSession else { return }
                
                // 1. 过滤出 .douyin.com 域名下的 Cookie
                let douyinCookies = cookies.filter { $0.domain.contains("douyin.com") }
                
                // 2. 必须包含核心会话凭据 sessionid 或 sessionid_ss
                let hasSession = douyinCookies.contains { cookie in
                    let name = cookie.name.lowercased()
                    let value = cookie.value.trimmingCharacters(in: .whitespacesAndNewlines)
                    return (name == "sessionid" || name == "sessionid_ss") && !value.isEmpty
                }
                
                guard hasSession else { return }
                
                // 3. 构建 Cookie 映射与请求头字符串
                var cookieMap: [String: String] = [:]
                for c in douyinCookies {
                    let name = c.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let val = c.value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty && !val.isEmpty {
                        cookieMap[name] = val
                    }
                }
                let rawCookieString = cookieMap.map { "\($0.key)=\($0.value);" }.joined(separator: " ")
                let cookieString = DouyinService.sanitizeCookieString(rawCookieString)
                guard !cookieString.isEmpty else { return }
                
                // 4. 防抖保护：若该 Cookie 串此前已被校验为未登录或无效，在 Cookie 发生实质变更前无需频繁重复发起 API 请求
                guard cookieString != self.lastVerifiedCookieString else { return }
                
                self.isVerifyingSession = true
                
                let runVerification = { [weak self] (inPageNickname: String?) in
                    Task { [weak self] in
                        guard let self = self else { return }
                        let status = await DouyinService.shared.verifySessionValidity(cookieString: cookieString)
                        
                        await MainActor.run {
                            self.isVerifyingSession = false
                            guard !self.hasSucceeded else { return }
                            
                            switch status {
                            case .valid(let nickname):
                                self.networkRetryCount = 0
                                let effectiveNickname = nickname ?? inPageNickname
                                self.completeLogin(cookieString: cookieString, cookieMap: cookieMap, nickname: effectiveNickname)
                                
                            case .invalid(let reason):
                                self.networkRetryCount = 0
                                self.lastVerifiedCookieString = cookieString
                                self.webView?.alphaValue = 1.0
                                print("ℹ️ [DouyinLoginSheet] 当前凭据未激活或未真正登录 (\(reason))，继续等待用户扫码/验证...")
                                
                            case .networkError(let err):
                                self.networkRetryCount += 1
                                print("⚠️ [DouyinLoginSheet] 在线验证接口网络波动 (\(self.networkRetryCount)): \(err)")
                                
                                // 严谨保护：绝不因重试次数盲目判定登录成功！
                                // 只有同源网页环境明确探测到有效用户昵称（证实用户已真实扫码授权），才允许作为有效登录放行
                                let cleanInPage = (inPageNickname != nil && inPageNickname != "抖音用户" && !inPageNickname!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? inPageNickname : nil
                                if let validNick = cleanInPage {
                                    print("🎉 [DouyinLoginSheet] 网页环境已确认真实登录成功 (\(validNick))，放行登录...")
                                    self.completeLogin(cookieString: cookieString, cookieMap: cookieMap, nickname: validNick)
                                } else {
                                    // 暂未确认真实登录，记录当前 Cookie 串防抖，保持在扫码卡片等待用户扫码，绝对不伪造已登录
                                    self.lastVerifiedCookieString = cookieString
                                    self.webView?.alphaValue = 1.0
                                }
                            }
                        }
                    }
                }
                
                // 优先在 WebView 内执行同源 JS 探针获取昵称（同源浏览器环境零风控、免证书/网络代理干扰）
                let jsFetchNick = """
                try {
                    let res = await fetch('/aweme/v1/web/user/profile/self/?aid=6383&device_platform=webapp', {
                        credentials: 'include',
                        headers: { 'Accept': 'application/json' }
                    });
                    let data = await res.json();
                    if (data && data.status_code === 0 && data.user && data.user.nickname) {
                        return data.user.nickname;
                    }
                } catch(e) {}
                return null;
                """
                
                if let wv = self.webView {
                    wv.callAsyncJavaScript(jsFetchNick, arguments: [:], in: nil, in: .page) { jsResult in
                        var inPageNickname: String? = nil
                        if case .success(let val) = jsResult {
                            inPageNickname = val as? String
                        }
                        runVerification(inPageNickname)
                    }
                } else {
                    runVerification(nil)
                }
            }
        }
        
        deinit {
            pollingTimer?.invalidate()
            cardCheckTimer?.invalidate()
            captchaRecoveryTimer?.invalidate()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // 开启开发者检查器调试支持（支持右键检查元素）
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        // 注入文档初建期（atDocumentStart）预置样式：从第 0 毫秒起彻底隐藏一切非登录卡片元素与自带关闭/返回按钮
        let preCSS = """
        html, body {
            background: transparent !important;
            overflow: hidden !important;
        }
        #dark,
        #light,
        #douyin-navigation,
        div[id*="navigation"],
        div[class*="navigation"],
        nav,
        aside,
        div[role="navigation"],
        #douyin-right-container,
        div[id*="right-container"],
        div[class*="right-container"],
        #douyin-header,
        header,
        #douyin-sidebar,
        div[id*="sidebar"],
        div[class*="sidebar"],
        [data-e2e="feed-active-video"],
        div[class*="video-player"],
        div[class*="video"],
        div[class*="feed"],
        #slidelist,
        #slidelist div[class*="slide"],
        #slidelist div[id*="slide"],
        div[class*="recommend"],
        div[class*="player"],
        #slidelist div[class*="loading"],
        #slidelist div[class*="spinner"],
        #slidelist div[class*="loader"],
        div[class*="feed"] div[class*="loading"],
        div[class*="feed"] div[class*="spinner"],
        div[class*="feed"] div[class*="loader"] {
            display: none !important;
            opacity: 0 !important;
            visibility: hidden !important;
            pointer-events: none !important;
        }
        .semi-modal-mask,
        div[class*="second_verify_mask"], [class*="second_verify_mask"],
        .secsdk_captcha_mask, [class*="captcha_mask"], [class*="captcha-mask"], [id*="captcha_mask"] {
            background: transparent !important;
        }
        [id*="login-full-panel"],
        #login-panel-new,
        .douyin_login_new_class,
        #douyin-login-new-id,
        .semi-modal-wrap,
        .semi-modal,
        [class*="second_verify"],
        [class*="second-verify"],
        #captcha_container,
        [class*="secsdk_captcha"],
        [class*="captcha_verify"] {
            opacity: 1 !important;
            pointer-events: auto !important;
        }
        /* 当存在二次身份验证卡片时，仅精准隐藏底层原始主登录卡片中的二维码与切换区域，绝不误伤二次验证卡片及其具体验证方式 */
        body:has([class*="second_verify"]) .douyin_login_new_class .UXzkscqE,
        body:has([class*="second_verify"]) .douyin_login_new_class .zzs0DGQV,
        body:has([class*="second_verify"]) .douyin_login_new_class .RyOwPUDZ,
        body:has([class*="second_verify"]) .douyin_login_new_class .hnHfmHGH,
        body:has([class*="second-verify"]) .douyin_login_new_class .UXzkscqE,
        body:has([class*="second-verify"]) .douyin_login_new_class .zzs0DGQV,
        body:has([class*="second-verify"]) .douyin_login_new_class .RyOwPUDZ,
        body:has([class*="second-verify"]) .douyin_login_new_class .hnHfmHGH,
        body:has([class*="verify_mask"]) .douyin_login_new_class .UXzkscqE,
        body:has([class*="verify_mask"]) .douyin_login_new_class .zzs0DGQV,
        body:has([class*="verify_mask"]) .douyin_login_new_class .RyOwPUDZ,
        body:has([class*="verify_mask"]) .douyin_login_new_class .hnHfmHGH,
        body:has([class*="passport-modal"]) .douyin_login_new_class .UXzkscqE,
        body:has([class*="passport-modal"]) .douyin_login_new_class .zzs0DGQV,
        body:has([class*="passport-modal"]) .douyin_login_new_class .RyOwPUDZ,
        body:has([class*="passport-modal"]) .douyin_login_new_class .hnHfmHGH {
            display: none !important;
            opacity: 0 !important;
            visibility: hidden !important;
            pointer-events: none !important;
        }
        /* 强力保障二次身份验证、安全验证及各具体验证组件（短信输入、按钮、二次二维码、画布等）完全正常呈现 */
        [class*="second_verify"],
        [class*="second-verify"],
        [class*="verify_mask"],
        [class*="passport-modal"],
        div[class*="second_verify"] *,
        div[class*="second-verify"] *,
        div[class*="verify"] *,
        div[class*="passport"] * {
            opacity: 1 !important;
            visibility: visible !important;
            pointer-events: auto !important;
        }
        /* 确保二次扫码中的二维码完全呈现 */
        div[class*="second_verify"] [class*="qrcode"],
        div[class*="second-verify"] [class*="qrcode"],
        div[class*="verify"] [class*="qrcode"],
        div[class*="passport"] [class*="qrcode"],
        div[class*="second_verify"] img,
        div[class*="second-verify"] img,
        div[class*="second_verify"] canvas,
        div[class*="second-verify"] canvas {
            display: block !important;
            opacity: 1 !important;
            visibility: visible !important;
            pointer-events: auto !important;
        }
        /* 保障滑动验证码（滑块、滑道、拼图碎块、背景底图及容器）正常置顶与交互，且不阻止验证完成后自然淡出与销毁 */
        #captcha_container,
        .secsdk_captcha_modal,
        [class*="secsdk_captcha_modal"],
        [class*="captcha_verify_container"],
        iframe[src*="captcha"],
        iframe[src*="verify"],
        #nocaptcha-container {
            z-index: 999999 !important;
            pointer-events: auto;
        }
        [data-savetik-captcha-hidden="true"],
        [data-savetik-captcha-hidden="true"] * {
            display: none !important;
            opacity: 0 !important;
            visibility: hidden !important;
            pointer-events: none !important;
        }
        .YoNA2Hyj, .qKr0RhiL,
        .close-gz62ZZ, div[class*="close-"], [class*="close-"],
        .semi-modal-close, [class*="modal-close"], [class*="close-btn"],
        [class*="closeIcon"], [class*="close-icon"],
        [aria-label="Close"], [aria-label="close"],
        .back-ZqcRC8, div[class*="back-"], [class*="back-"],
        .semi-modal-back, [class*="modal-back"], [class*="back-btn"],
        [class*="backIcon"], [class*="back-icon"],
        [aria-label="Back"], [aria-label="back"], [aria-label="Return"] {
            opacity: 0 !important;
            visibility: hidden !important;
            pointer-events: none !important;
        }
        """
        let preScript = WKUserScript(
            source: """
            let style = document.createElement('style');
            style.id = 'savetik-pre-style';
            style.innerHTML = `\(preCSS)`;
            (document.head || document.documentElement).appendChild(style);
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(preScript)
        
        // 注入跨 frame 验证码成功检测脚本（在所有主框架与 iframe 中监听滑动验证码成功信号）
        let captchaWatcherScript = WKUserScript(
            source: """
            (function() {
                if (window.__savetik_watcher_injected) return;
                window.__savetik_watcher_injected = true;
                
                // 物理交互门禁：记录用户是否真实按住并拖动了滑块
                window.__savetik_user_dragged = false;
                window.__savetik_is_pointer_down = false;
                window.__savetik_drag_start_x = 0;
                
                function isTargetInCaptcha(t) {
                    if (!t || !(t instanceof Element)) return false;
                    return !!(t.closest('#captcha_container') ||
                              t.closest('.secsdk_captcha_modal') ||
                              t.closest('[class*="secsdk"]') ||
                              t.closest('[class*="captcha"]') ||
                              t.closest('[class*="slide"]') ||
                              t.closest('[class*="drag"]'));
                }
                
                function setGlobalDragged() {
                    window.__savetik_user_dragged = true;
                    try {
                        if (window.top) {
                            window.top.__savetik_user_dragged = true;
                        }
                    } catch(e) {}
                }
                
                function resetGlobalDragged() {
                    window.__savetik_user_dragged = false;
                    window.__savetik_is_pointer_down = false;
                    try {
                        if (window.top) {
                            window.top.__savetik_user_dragged = false;
                            window.top.__savetik_is_pointer_down = false;
                        }
                    } catch(e) {}
                }
                
                function checkHasUserDragged() {
                    if (window.__savetik_user_dragged) return true;
                    try {
                        if (window.top && window.top.__savetik_user_dragged) return true;
                    } catch(e) {}
                    return false;
                }
                
                // 监听按下（包含 pointerdown 与 mousedown）
                document.addEventListener('pointerdown', function(e) {
                    try {
                        if (isTargetInCaptcha(e.target)) {
                            window.__savetik_is_pointer_down = true;
                            window.__savetik_drag_start_x = e.clientX || 0;
                            window.__savetik_captcha_success_reported = false;
                            window.__savetik_captcha_success_fired = false;
                            try {
                                if (window.top) {
                                    window.top.__savetik_is_pointer_down = true;
                                    window.top.__savetik_drag_start_x = e.clientX || 0;
                                    window.top.__savetik_captcha_success_reported = false;
                                    window.top.__savetik_captcha_success_fired = false;
                                }
                            } catch(tErr) {}
                        }
                    } catch(err) {}
                }, true);
                
                // 监听滑动移动，位移 > 20px 时才确认发生过真实物理拖动
                document.addEventListener('pointermove', function(e) {
                    try {
                        let isDown = window.__savetik_is_pointer_down;
                        let startX = window.__savetik_drag_start_x;
                        try {
                            if (!isDown && window.top) {
                                isDown = window.top.__savetik_is_pointer_down;
                                startX = window.top.__savetik_drag_start_x;
                            }
                        } catch(e) {}
                        
                        if (isDown) {
                            let diff = Math.abs((e.clientX || 0) - startX);
                            if (diff > 20) {
                                setGlobalDragged();
                            }
                        }
                    } catch(err) {}
                }, true);
                
                document.addEventListener('pointerup', function() {
                    window.__savetik_is_pointer_down = false;
                    try {
                        if (window.top) window.top.__savetik_is_pointer_down = false;
                    } catch(e) {}
                }, true);
                
                function notifyCaptchaSuccess() {
                    try {
                        if (window.__savetik_card_displayed || window.__savetik_in_mfa) return;
                        if (window.top && (window.top.__savetik_card_displayed || window.top.__savetik_in_mfa)) return;
                    } catch(e) {}
                    
                    // 门禁：用户必须真正按住并发生过拖动！杜绝一切零操作冷启动误报
                    if (!checkHasUserDragged()) return;
                    
                    if (window.__savetik_captcha_success_reported) return;
                    window.__savetik_captcha_success_reported = true;
                    try {
                        if (window.top) window.top.__savetik_captcha_success_reported = true;
                    } catch(e) {}
                    
                    try {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.savetikCaptchaSuccess) {
                            window.webkit.messageHandlers.savetikCaptchaSuccess.postMessage('success');
                        }
                    } catch(e) {}
                }
                
                // 1. 监听 window message 广播（捕获跨域 iframe 成功事件）
                window.addEventListener('message', function(e) {
                    try {
                        try {
                            if (window.__savetik_card_displayed || window.__savetik_in_mfa) return;
                            if (window.top && (window.top.__savetik_card_displayed || window.top.__savetik_in_mfa)) return;
                        } catch(e) {}
                        
                        // 若用户未拖动滑块，直接阻断
                        if (!checkHasUserDragged()) return;
                        
                        let d = e.data;
                        let s = typeof d === 'string' ? d : JSON.stringify(d);
                        if (!s || s.includes('second_verify') || s.includes('second-verify') || s.includes('passport')) return;
                        
                        let sLower = s.toLowerCase();
                        // 严防初始化、重置、改变尺寸等消息误伤
                        if (sLower.includes('"init"') || sLower.includes('"ready"') || sLower.includes('"resize"') || sLower.includes('"reset"')) {
                            return;
                        }
                        // 剔除模糊匹配 'pass'，精准匹配验证成功动作
                        let isValidateSuccess = sLower.includes('validate_success') ||
                                                sLower.includes('"status":"success"') ||
                                                sLower.includes('"action":"success"') ||
                                                sLower.includes('"event":"success"') ||
                                                sLower.includes('"result":"success"');
                        if ((sLower.includes('secsdk') || sLower.includes('captcha')) && isValidateSuccess) {
                            notifyCaptchaSuccess();
                        }
                    } catch(err) {}
                });
                
                // 2. 监听本 frame（主页面或验证码 iframe）内的 DOM 文字变化
                let observer = new MutationObserver(function() {
                    try {
                        try {
                            if (window.__savetik_card_displayed || window.__savetik_in_mfa) return;
                            if (window.top && (window.top.__savetik_card_displayed || window.top.__savetik_in_mfa)) return;
                        } catch(e) {}
                        let text = (document.body ? document.body.innerText : '') || '';
                        if (text.includes('选择验证方式') || text.includes('身份验证') || text.includes('安全验证')) return;
                        
                        // 若出现重试提示，说明此前滑动未通过，重置物理拖动状态
                        if (text.includes('验证失败') || text.includes('请重新尝试') || text.includes('请控制滑块拼合图像')) {
                            resetGlobalDragged();
                            return;
                        }
                        
                        // 只有在拖动过且明确出现成功文字时才触发
                        if (checkHasUserDragged() && (text.includes('滑动成功') || text.includes('拼图成功') || text.includes('验证通过'))) {
                            notifyCaptchaSuccess();
                        }
                    } catch(err) {}
                });
                
                function startObserve() {
                    let target = document.body || document.documentElement;
                    if (target) {
                        observer.observe(target, { childList: true, subtree: true, characterData: true });
                    }
                }
                
                if (document.body) {
                    startObserve();
                } else {
                    window.addEventListener('DOMContentLoaded', startObserve);
                }
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(captchaWatcherScript)
        
        // 注册弱引用脚本消息处理器，接收网页端登录状态与返回按钮状态回调
        let weakHandler = WeakScriptMessageHandler(delegate: context.coordinator)
        config.userContentController.add(weakHandler, name: "savetikLogin")
        config.userContentController.add(weakHandler, name: "savetikBackState")
        config.userContentController.add(weakHandler, name: "savetikCaptchaSuccess")
        
        let dataStore = WKWebsiteDataStore.default()
        config.websiteDataStore = dataStore
        
        let webView = WKWebView(frame: .zero, configuration: config)
        context.coordinator.webView = webView
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // 启用深层检查器支持 (macOS 13.3+)
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        
        webView.alphaValue = 1.0
        // 设置背景完全透明以融合液态玻璃
        webView.setValue(false, forKey: "drawsBackground")
        
        // 挂载 CookieStore 监听
        dataStore.httpCookieStore.add(context.coordinator)
        
        // 彻底清理可能残留的旧鉴权凭据，待清理确认完成后再开启会话轮询（保留设备标识与安全环境缓存）
        dataStore.httpCookieStore.getAllCookies { cookies in
            let staleAuthCookies = cookies.filter { c in
                let n = c.name.lowercased()
                return n == "sessionid" || n == "sessionid_ss" || n == "sid_guard" || n == "sid_tt" || n.contains("uid_tt")
            }
            let group = DispatchGroup()
            for c in staleAuthCookies {
                group.enter()
                dataStore.httpCookieStore.delete(c) {
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                context.coordinator.startPollingTimer(in: dataStore.httpCookieStore, webView: webView)
            }
        }
        
        if let url = URL(string: "https://www.douyin.com/?modal_id=login_douyin") {
            let request = URLRequest(url: url)
            webView.load(request)
            context.coordinator.startCardDetection(in: webView)
        }
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.parent = self
        // 弹窗关闭或登录成功时立即隐藏底层 webView，绝不留残影或闪现网页
        if isDismissing || isSuccess {
            nsView.alphaValue = 0
        }
        // 响应 Swift 端点击返回按钮
        if context.coordinator.lastHandledBackTrigger != backTrigger {
            context.coordinator.lastHandledBackTrigger = backTrigger
            context.coordinator.triggerBack()
        }
    }
    
    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.websiteDataStore.httpCookieStore.remove(coordinator)
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "savetikLogin")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "savetikBackState")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "savetikCaptchaSuccess")
        coordinator.pollingTimer?.invalidate()
        coordinator.pollingTimer = nil
        coordinator.cardCheckTimer?.invalidate()
        coordinator.cardCheckTimer = nil
        coordinator.captchaRecoveryTimer?.invalidate()
        coordinator.captchaRecoveryTimer = nil
        nsView.stopLoading()
        nsView.loadHTMLString("", baseURL: nil)
        nsView.alphaValue = 0
    }
}
