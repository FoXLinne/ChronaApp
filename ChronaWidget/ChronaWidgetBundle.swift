import WidgetKit
import SwiftUI

@main
struct ChronaWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayFocusWidget()
        CountdownEventWidget()
        MonthHeatmapWidget()
        ChronaWidgetLiveActivity()
    }
}
