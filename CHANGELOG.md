## 📜 Version History

### v3.5.2 (2026-02-09)
- Address issue #60, app hanging if no groups are present.

### v3.5.1 (2026-01-21)
- Address issue #58, import button not working on macOS 26 (Tahoe).

### v3.5.0 (2026-01-15)
- Add self built XML parser and remove 3rd party parser (SwiftXML)

### v3.4.0 (2025-12-24)
- Add basic hardware, OS, and application usage collection
- Data is sent anonymously to [TelemetryDeck](https://telemetrydeck.com) to aid in development
- View 'About Prune' to opt out of sending data
- Address items in issue #55
- Add ability to remove scoped disabled policies

### v3.3.0 (2025-04-14)
- Include printers as an available object to scan
- Update for Sequoia and accessing shared data
- Misc fixes and cleanup

### v3.2.2 (2024-09-26)
- Fix crash when exporting after an import
- Fix title being truncated (full name now appears as a tooltip)

### v3.2.1 (2024-02-09)
- Query App Installers for groups used for scoping

### v3.2.0 (2024-02-04)
- Update login window
- Add support for bearer token authentication
- Provide alert if some lookups fail, which may result in inaccurate results

### v3.1.1 (2023-10-15)
- Fix issue #42
- Updated token refresh process to address issue #41
- Improved logging

### v3.1.0 (2023-09-16)
- Fix issue #39: double quotes in display name
- Better handling of bearer token expiration
- Fix export to CSV for policies
- Enable sharing of keychain items with other apps by the same developer

### v3.0.2 (2023-07-14)
- Guard against faulty package configurations in computer prestages
- Check for extension attributes used only on the display tab of advanced searches

### v3.0.1 (2023-04-07)
- Updated logging to prevent potential looping

### v3.0.0 (2023-03-21)
- Updated UI
- Add ability to export results to a CSV (Option-click Export)

### v2.4.0 (2023-03-08)
- Add scanning of Mac Apps

### v2.3.3 (2022-11-18)
- Fix issue where extension attributes used as criteria in smart groups were listed as unused

### v2.3.2 (2022-11-18)
- Fix computer/mobile device extension attributes not deleting (#29)

### v2.3.1 (2022-11-16)
- Fix issue where policies that are disabled and scoped were not showing up as unused (#27)

### v2.3.0 (2022-11-15)
- List policies that are disabled and still scoped (#27)
- List computer extension attributes that are disabled (marked with `[disabled]`)
- Scan advanced searches (#26) for groups and extension attributes used as criteria
- Adjust URL to view unused scripts based on Jamf Pro version

### v2.2.5 (2022-07-27)
- Resolve crash when importing

### v2.2.4 (2022-04-25)
- Fix crash when scanning only computer (configuration) profiles
- Add keyboard shortcut and menu bar item (View → Logs Folder) to open logs folder

### v2.2.3 (2022-04-21)
- Fix some potential authentication issues
- Add deterministic progress wheel to show current status while deleting items

### v2.2.2 (2022-02-17)
- Add token authentication to the classic API for Jamf Pro 10.35+
- Add feedback while items are being deleted from the Jamf Pro server
- Fix removal warning always showing 0 items (#13)
- Fix items not getting deleted when importing files (#14)
- Fix crash that could occur if computer groups were not scanned (#15)
- Fix packages in patch policies not being picked up (#16)

### v2.2.1 (2022-01-17)
- Layout changed with dedicated login window
- Added restricted software as an item to query
- Changed Remove button to Delete

### v1.3.1 (2021-09-23)
- Fixed issue where eBooks and classes were not getting deleted
- Updated URL used for token request from Jamf Pro API
- Corrected extra comma in exported items
- Added export summary

### v1.3.0 (2021-05-30)
- Scan computer prestages for packages and configuration profiles
- Remove check against computer configurations
- Fix app crash when only classes is selected
- Fix issue of duplicate API calls
- Additional error handling

### v1.3.0 (2021-05-23)
- Added scan against eBooks and Classes

### v1.2.0 (2020-10-06)
- Guard against corrupt policies/scripts (having no name)
- Added warning before deleting is initiated
- Write logging information to `~/Library/Containers/com.jamf.pse.prune/Data/Library/Logs/Prune.log`

