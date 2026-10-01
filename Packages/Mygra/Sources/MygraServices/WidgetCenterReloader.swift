//
//  WidgetCenterReloader.swift
//  MygraServices
//
//  Production `WidgetTimelineReloading` over WidgetCenter.
//

import Foundation
import MygraCore
#if canImport(WidgetKit)
import WidgetKit
#endif

public struct WidgetCenterReloader: WidgetTimelineReloading {
    nonisolated public init() {}

    public func reloadTimelines(ofKind kind: String) {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        #endif
    }
}
