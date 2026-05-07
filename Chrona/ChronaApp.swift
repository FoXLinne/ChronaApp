//
//  ChronaApp.swift
//  Chrona
//
//  Created by KaedeKR on 2026/4/16.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

@main
struct ChronaApp: App {
    @StateObject private var appModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @UIApplicationDelegateAdaptor(ChronaAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appModel)
                .preferredColorScheme(appModel.applyTheme())
                .onChange(of: scenePhase) { _, phase in
                    appModel.handleScenePhaseChange(phase)
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "chrona" else { return }
        switch url.host() {
        case "statistics":
            appModel.selectedTab = .statistics
        case "countdown":
            appModel.selectedTab = .countdown
        case "active":
            appModel.selectedTab = .active
        default:
            break
        }
    }
}
