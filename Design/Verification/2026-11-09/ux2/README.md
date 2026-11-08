# Dashboard UX pass, 2026-11-09

Branch `claude/ux-dashboard`. Unsigned build on a private iPhone 18 Pro simulator (deleted afterwards), launched with
`-MygraDebugLocalStore YES -isOnboardingComplete YES -Plus.grandfathered YES` plus a DEBUG scenario:
`-MygraDebugScenario dashRecent|dashDays|dashQuiet|dashActive` (last attack ended 16 h / 3 d / 12 d ago, or ongoing),
and `-MygraDebugHealth connected` for canned Health stats. Simulators have no Apple Intelligence or WeatherKit, so the
Migraine Assistant card is absent and the weather card shows its unavailable state.

| File | State |
| --- | --- |
| `before-recent-nohealth.png` | Before: "Last migraine today" in header and pill, em dash, large red Connect Health above insights |
| `after-recent-nohealth.png` | "Last migraine 16 hours ago", pill is only "Log a Migraine", insights first, compact Health row |
| `after-recent-health.png` | Health connected: full Today card, after Quick Bits |
| `after-days-nohealth.png` | "Last migraine 3 days ago" |
| `after-quiet-nohealth.png` | "No migraines in 12 days" (gradient accent) |
| `after-active-nohealth.png` | "Migraine in progress", pill keeps the live Ongoing timer |

Card order (iPhone): header, finish-logging, medication overuse, weather, assistant, Quick Bits, Today.
Weather and assistant are unchanged and stay above Quick Bits.
