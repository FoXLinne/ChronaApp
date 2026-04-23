//
//  ChronaWidgetLiveActivity.swift
//  ChronaWidget
//
//  Created by KaedeKR on 2026/4/23.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ChronaWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ChronaWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChronaWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension ChronaWidgetAttributes {
    fileprivate static var preview: ChronaWidgetAttributes {
        ChronaWidgetAttributes(name: "World")
    }
}

extension ChronaWidgetAttributes.ContentState {
    fileprivate static var smiley: ChronaWidgetAttributes.ContentState {
        ChronaWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ChronaWidgetAttributes.ContentState {
         ChronaWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ChronaWidgetAttributes.preview) {
   ChronaWidgetLiveActivity()
} contentStates: {
    ChronaWidgetAttributes.ContentState.smiley
    ChronaWidgetAttributes.ContentState.starEyes
}
