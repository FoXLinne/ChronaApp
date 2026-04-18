//
//  ChronaApp.swift
//  Chrona
//
//  Created by KaedeKR on 2026/4/16.
//

import SwiftUI

@main
struct ChronaApp: App {
    @StateObject private var appModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appModel)
                .preferredColorScheme(appModel.applyTheme())
                .onChange(of: scenePhase) { _, phase in
                    appModel.handleScenePhaseChange(phase)
                }
        }
    }
}


