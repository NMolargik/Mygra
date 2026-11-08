# One entry point for logging, 2026-11-09

Branch `claude/ux-plus`. From iOS 26 the bottom "Log a Migraine" pill is the only way to log on Dashboard, Calendar and
Migraines; the top-right red "+" (and the ongoing-migraine shortcut button next to it) is no longer installed there.
Before iOS 26 there is no pill, so the toolbar "+" stays on those three tabs. Settings never had either.
Command-N still works through the menu-bar command (`MygraCommands`), and the pill keeps Command-L.

Captured on private simulators (iPhone 18 Pro, iPad Pro 13-inch M5, iOS 27.2, deleted afterwards) with
`-MygraDebugLocalStore YES -isOnboardingComplete YES -Plus.grandfathered YES -MygraDebugScenario dashRecent`
and a DEBUG-only `-MygraDebugTab Dashboard|Calendar|Migraines` launch argument added for these captures.

| File | State |
| --- | --- |
| `before-iphone-Dashboard.png` | "+" top right and the pill |
| `after-iphone-Dashboard.png` | pill only |
| `before/after-iphone-Calendar.png` | Calendar keeps its "..." menu, "+" removed |
| `before/after-iphone-Migraines.png` | Migraines keeps its menu and search, "+" removed |
| `before/after-ipad-Dashboard.png` | iPad already shows the pill across the bottom; "+" removed |
