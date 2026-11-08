# Attack Mode verification, 2026-11-08

Branch `claude/attack-mode`. Built unsigned (`CODE_SIGNING_ALLOWED=NO`) for the simulator and run on
iPhone 18 Pro (B3F2034F) and Apple Watch Series 12 46mm (4155A986).

| File | What it shows |
| --- | --- |
| `iphone-attack-mode.png` | Attack Mode on iPhone: near-black background, dim amber text, five big pain steps (8 selected), usual medications, a logged-dose confirmation line, End Attack. No images, no animation. |
| `iphone-finish-logging-card.png` | Dashboard "Finish logging your migraine" card after End Attack (the attack was started, rated, medicated, and ended through the real model). |
| `iphone-settings-attack-mode.png` | Settings > Attack Mode: Finish-Logging Reminder toggle and "Remind Me After" (default 2 hours). |
| `watch-attack-mode.png` | Watch Attack Mode (top of the scrolling screen: elapsed time, pain steps). |

How these were produced: simctl only (no tapping). A DEBUG-only launch argument
(`-MygraDebugScenario attackActive|attackEnded`, `-MygraDebugLocalStore YES`, `-MygraDebugTab settings`)
drives `AttackModeModel` through the same use-cases the buttons call. The watch status was seeded in its
App Group defaults because the simulated watch/phone pair was not reachable.

Known, not bright by our doing: the iOS status bar/home indicator and the watch status icons are drawn by the system.
