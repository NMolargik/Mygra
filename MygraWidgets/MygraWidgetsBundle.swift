//
//  MygraWidgetsBundle.swift
//  MygraWidgets
//
//  Created by Nick Molargik on 8/29/25.
//

import WidgetKit
import SwiftUI

@main
struct MygraWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Only the Live Activity, per request to clear out all timeline widgets.
        MygraWidgetsLiveActivity()
    }
}

