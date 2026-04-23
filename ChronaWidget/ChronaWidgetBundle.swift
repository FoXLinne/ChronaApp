//
//  ChronaWidgetBundle.swift
//  ChronaWidget
//
//  Created by KaedeKR on 2026/4/23.
//

import WidgetKit
import SwiftUI

@main
struct ChronaWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChronaWidget()
        ChronaWidgetControl()
        ChronaWidgetLiveActivity()
    }
}
