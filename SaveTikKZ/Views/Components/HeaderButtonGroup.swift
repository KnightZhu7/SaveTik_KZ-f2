//
//  HeaderButtonGroup.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 4/21/26.
//

import SwiftUI
import AppKit
import Combine
import WebKit

struct HeaderButtonGroup: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var selectedAppearance: AppAppearance
    @Binding var showFilterPopover: Bool
    
    @AppStorage("SaveTik_CustomCookie") private var customCookie: String = ""
    
    @State private var appearanceHovered = false
    @State private var filterHovered = false
    @State private var selectedLoginAction: String? = nil
    
    // 监听 Option 键状态
    @State private var isOptionPressed = false
    @State private var flagsMonitor: Any?
    
    private let hoverInset: CGFloat = 3
    
    var body: some View {
        let isImageMode = !viewModel.imageList.isEmpty
        let hasResults = !viewModel.isFetching && (isImageMode || !viewModel.videoList.isEmpty)
        let isLoggedIn = customCookie.contains("sessionid=")
        // 🔥 新增：是否允许使用 Option 筛选功能（必须同时拥有 Live 和 JPEG）
        let canFilterImages = viewModel.hasMixedImageTypes
        
        HStack(spacing: 0) {
            // 按钮 1：筛选 / 网格切换（有结果时）或者 登录相关设置（无解析结果时）
            if hasResults {
                Button {
                    if isImageMode {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                            if isOptionPressed && canFilterImages {
                                viewModel.imageFilterMode = viewModel.imageFilterMode.next
                            } else {
                                viewModel.preferredGridColumns = viewModel.preferredGridColumns == 2 ? 3 : 2
                            }
                        }
                    } else {
                        showFilterPopover.toggle()
                    }
                } label: {
                    buttonIcon(
                        systemName: isImageMode
                            ? ((isOptionPressed && canFilterImages) ? viewModel.imageFilterMode.icon : (viewModel.preferredGridColumns == 2 ? "rectangle.grid.2x2" : "square.grid.3x2"))
                            : "line.3.horizontal.decrease",
                        enabled: true,
                        hovered: filterHovered,
                        isHighlighted: false
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())
                .onHover { filterHovered = $0 }
                .popover(isPresented: $showFilterPopover, arrowEdge: .top) {
                    FilterPopoverView(viewModel: viewModel)
                }
                .help(isImageMode ? ((isOptionPressed && canFilterImages) ? "切换过滤模式 (当前: \(filterModeName))" : (viewModel.preferredGridColumns == 2 ? "最少 2 列" : "最少 3 列")) : "筛选")
                .padding(.leading, hoverInset)
                .padding(.vertical, hoverInset)
            } else if !isLoggedIn {
                // 无结果且未登录：图标为 person.circle，点击直接弹出登录窗口
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.showDouyinLoginModal = true
                    }
                } label: {
                    buttonIcon(
                        systemName: "person.circle",
                        enabled: !viewModel.isFetching,
                        hovered: filterHovered,
                        isHighlighted: false
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())
                .disabled(viewModel.isFetching)
                .onHover { hovering in
                    filterHovered = viewModel.isFetching ? false : hovering
                }
                .help(viewModel.isFetching ? "" : "登录抖音账号")
                .padding(.leading, hoverInset)
                .padding(.vertical, hoverInset)
            } else {
                // 无结果且已登录：图标为 person.crop.circle.badge.ellipsis，点击展开“登录设置”菜单（与外观模式一致使用 Picker 确保 macOS 显示图标）
                Menu {
                    Picker("登录设置", selection: Binding<String?>(
                        get: { selectedLoginAction },
                        set: { action in
                            selectedLoginAction = nil // 立即置空，确保每次点击相同项都能触发状态变更
                            guard let action = action else { return }
                            if action == "check" {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    viewModel.showDouyinLoginModal = true
                                }
                            } else if action == "logout" {
                                clearCustomCookie()
                            }
                        }
                    )) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                            Text("检查登录")
                        }
                        .tag("check" as String?)
                        
                        HStack {
                            Image(systemName: "person.crop.circle.badge.xmark")
                            Text("退出登录")
                        }
                        .tag("logout" as String?)
                    }
                    .pickerStyle(.inline)
                } label: {
                    buttonIcon(
                        systemName: "person.crop.circle.badge.ellipsis",
                        enabled: !viewModel.isFetching,
                        hovered: filterHovered,
                        isHighlighted: false
                    )
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .contentShape(Capsule())
                .disabled(viewModel.isFetching)
                .onHover { hovering in
                    filterHovered = viewModel.isFetching ? false : hovering
                }
                .help(viewModel.isFetching ? "" : "登录设置")
                .padding(.leading, hoverInset)
                .padding(.vertical, hoverInset)
            }
            
            // 中间竖线
            Rectangle()
                .fill(Color.primary.opacity(0.15))
                .frame(width: 1, height: 16)
                .opacity((appearanceHovered || filterHovered) ? 0 : 1)
            
            // 按钮 2：仅用于外观模式切换（右），去除所有登录相关选项
            Menu {
                Picker("外观模式", selection: $selectedAppearance) {
                    ForEach(AppAppearance.allCases) { mode in
                        HStack {
                            Image(systemName: mode.icon)
                            Text(mode.rawValue)
                        }.tag(mode)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                buttonIcon(
                    systemName: "ellipsis",
                    enabled: true,
                    hovered: appearanceHovered,
                    isHighlighted: false
                )
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .contentShape(Capsule())
            .onHover { appearanceHovered = $0 }
            .help("外观模式")
            .padding(.trailing, hoverInset)
            .padding(.vertical, hoverInset)
        }
        .glassEffect(.regular, in: .capsule)
        .id(selectedAppearance)
        .animation(.easeInOut(duration: 0.12), value: appearanceHovered)
        .animation(.easeInOut(duration: 0.12), value: filterHovered)
        .animation(.easeInOut(duration: 0.15), value: viewModel.isFetching)
        .onChange(of: viewModel.isFetching) { _, isFetching in
            if isFetching {
                showFilterPopover = false
                filterHovered = false
            }
        }
        .onAppear {
            flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isOptionPressed = event.modifierFlags.contains(.option)
                }
                return event
            }
            isOptionPressed = NSEvent.modifierFlags.contains(.option)
        }
        .onDisappear {
            if let monitor = flagsMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
    
    private func clearCustomCookie() {
        customCookie = ""
        DouyinService.clearAllAuthCookies()
    }
    
    // 辅助计算当前筛选模式的中文名称
    private var filterModeName: String {
        switch viewModel.imageFilterMode {
        case .all: return "显示全部"
        case .liveOnly: return "仅 Live 图"
        case .jpegOnly: return "仅静态图"
        }
    }
    
    @ViewBuilder
    private func buttonIcon(
        systemName: String,
        enabled: Bool,
        hovered: Bool,
        isHighlighted: Bool
    ) -> some View {
        let buttonSize: CGFloat = 36
        let hoverWidth  = buttonSize - hoverInset
        let hoverHeight = buttonSize - 2 * hoverInset
        
        ZStack {
            Capsule()
                .fill(Color.primary.opacity((hovered && enabled) ? 0.14 : 0))
            
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundColor(isHighlighted ? AppTheme.accentBlue : (enabled ? .primary : .secondary))
                .opacity(enabled ? 1.0 : 0.45)
        }
        .frame(width: hoverWidth, height: hoverHeight)
    }
}
