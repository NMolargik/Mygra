# Log pill gets visual weight, 2026-11-09

Branch `claude/ux-pill2`. The "Log a Migraine" bottom accessory (iOS 26+) now holds a filled purple capsule with white
text and the plus glyph, centered in the accessory. On regular width (iPad) the capsule is capped at 360 pt instead of
filling the whole strip (the accessory itself cannot be sized through the API). The fill is `mygraPurple` mixed 12% with
black: white on the pure brand purple is about 4.4:1, on the deepened fill about 5.3:1, identical in light and dark.
The active-attack variant keeps its layout, with a soft purple capsule behind it, the elapsed time in primary color and
the same width cap. Identifiers `accessoryLogButton`, `ongoingMigraineAccessory` and Command-L are unchanged. No new strings.

Captured on private simulators (iPhone 18 Pro, iPad Pro 13-inch M5, iOS 27.2, deleted afterwards) with
`-MygraDebugLocalStore YES -isOnboardingComplete YES -Plus.grandfathered YES -MygraDebugHealth connected
-MygraDebugTab Dashboard -MygraDebugScenario dashRecent|dashActive` (`-MygraDebugHealth connected` also keeps the
HealthKit permission sheet away from the capture).

Files: `{before,after}-{iphone,ipad}-Dashboard-{light,dark}.png` (log pill) and
`{before,after}-{iphone,ipad}-Active-{light,dark}.png` (ongoing attack pill).
