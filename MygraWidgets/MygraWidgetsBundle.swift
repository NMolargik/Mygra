//
//  MygraWidgetsBundle.swift
//  MygraWidgets
//

import WidgetKit
import SwiftUI

@main
struct MygraWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MygraWidgetsLiveActivity()
        MygraWidgetsDaysSinceLastMigraine()
    }
}
