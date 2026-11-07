# Mygra 2.0 feature verification, 2026-11-07

Simulator: iPhone 18 Pro (iOS 27.0), Debug build of main.

## Enabling Plus (no in-app debug switch exists)
    xcrun simctl spawn <udid> defaults write com.molargiksoftware.Mygra Plus.grandfathered -bool true
Relaunch; Settings shows "Mygra Plus: Early supporter".

## Test data
Settings > Developer Tools > Generate Test Data (DEBUG). Now seeds triptan doses on 11 days
in the last 30 (over the 10-day limit), ibuprofen on 9 (approaching the 15-day limit), and
older attacks 5-8 weeks back.

## Files
- 01-dashboard-overuse-card.png: overall + triptan threshold, simple analgesic approaching, AMF link, "not medical advice" wording
- 02-report-setup-midas.png: report setup; MIDAS 10 (Grade II)
- clinical-report-3-month.pdf (generated before the heading-orphan fix), clinical-report-1-month.pdf
- report-*.png: rendered pages

## Defects fixed
1. PDF export crashed (exclusivity violation in PDFReportRenderer.drawTable) - 172d9c1
2. MIDAS stepper "1 days" - e93e962
3. Section headings stranded at page bottom - see git log
