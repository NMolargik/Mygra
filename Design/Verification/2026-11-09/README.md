# Cycle correlation and pressure graph verification, 2026-11-09

Branch `claude/cycle-pressure`. Built unsigned (`CODE_SIGNING_ALLOWED=NO`), run on a private iPhone 18 Pro
simulator ("Mygra Verify iPhone", deleted afterwards). Launched with
`-MygraDebugLocalStore YES -MygraDebugScenario cyclePressure -Plus.grandfathered YES -isOnboardingComplete YES`.
The DEBUG-only `cyclePressure` scenario seeds 15 attacks, six periods (28-day cycles, 5 flow days) and a canned
hourly pressure series with three drops (one forecast), because simulators have no HealthKit entitlement or WeatherKit.
Extra DEBUG launch args only scroll or expand screens for capture: `-MygraDebugTab calendar|settings`,
`-MygraDebugDashboardScroll pressure|cycle`, `-MygraDebugSettingsScroll cycle`, `-MygraDebugPressureOpen YES`,
`-MygraDebugTuning YES`, `-MygraDebugScrollBottom YES`.

| File | What it shows |
| --- | --- |
| `calendar-overlay.png` | Calendar with pink period days (Nov 3-7, drop marker) and a legend line. Attack dots still show on top. |
| `quickbits-cycle.png` | The cycle statistic as the first Quick Bits row: "67% ... about 3.1 times what chance would predict", basis line below. |
| `pdf-cycle-section.png` | Clinical PDF page with the "Menstrual Cycle Pattern" section (rendered from the app's own PDF). |
| `dashboard-after.png` | Dashboard, collapsed pressure line inside the weather card ("Pressure drop forecast"). |
| `pressure-graph.png` | Weather card expanded: 72-hour graph (48 h past, 24 h forecast dashed), shaded flagged drops, attack marker, summary. |
| `pressure-threshold.png` | Alert threshold open: drop size stepper, window picker, plain-language explanation. |
| `before-settings-pill.png` / `settings-after.png` | Settings before and after hiding the floating Log pill on that tab. |
| `before-dashboard-pill.png` | Dashboard with the pill (unchanged on Dashboard, Calendar, Migraines; `dashboard-after.png` is the same strip). |
| `settings-cycle.png` | Settings > Cycle Insights toggle with the empty-data footer (pre-pin build; Health has no data on a simulator). |
