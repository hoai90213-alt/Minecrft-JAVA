# NativesSwift

This folder is an isolated Swift workspace for UI migration.

Goals:
- Keep current Objective-C launcher logic untouched.
- Rebuild UI screens in Swift step by step.
- Migrate safely screen-by-screen instead of full rewrite.

Current scope in this folder:
- `Design/GlassTheme.swift`: shared visual tokens for dark smoky glass style.
- `Menu/DashboardMenuItem.swift`: menu item model for icon-first sidebar.
- `Menu/SwiftLauncherMenuViewController.swift`: compact icon-only menu screen.
- `Bridge/SwiftMenuFactory.swift`: simple factory entry point for Objective-C hosting later.

Important:
- Nothing in this folder is wired into CMake yet.
- Existing build flow remains unchanged.

Suggested migration order:
1. Hook `SwiftMenuFactory` into `LauncherSplitViewController` as an experiment.
2. Keep navigation callbacks in Objective-C while replacing only view rendering.
3. Move settings/profile rows to Swift after menu is stable.
4. Remove old Objective-C screen only after parity testing.
