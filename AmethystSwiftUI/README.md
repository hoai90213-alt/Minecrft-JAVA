# AmethystSwiftUI

Standalone SwiftUI variant of Amethyst iOS.

This folder is intentionally separate from the current Objective-C/CMake launcher.
It is the starting point for a full SwiftUI app line that can be developed and shipped independently.

## What is included
- Full SwiftUI app shell with iPhone-first layout.
- Dark smoky glass visual system.
- Dashboard/Home, Profiles, Installer, Accounts, Settings screens.
- Installer search:
  - Modrinth public search.
  - CurseForge search (requires API key in settings).
- Persistent dashboard preferences:
  - `general.dashboard_background_mode`
  - `general.dashboard_background_path`
  - `general.dashboard_blur_strength`
  - `general.dashboard_glass_intensity`
- Persistent installer key:
  - `general.curseforge_api_key`
- Core bridge protocol (`LauncherCore`) with mock implementation.
- Objective-C bridge stub for later runtime integration.

## What is not included yet
- Direct runtime wiring to native launch/install logic.
- Existing C/Objective-C render/runtime internals.

## Generate Xcode project
Requirements:
- macOS
- Xcode
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

Commands:
```bash
cd AmethystSwiftUI
./Scripts/generate_project.sh
open AmethystSwiftUI.xcodeproj
```

## GitHub CI (separate lane)
- Workflow: `.github/workflows/swiftui-development.yml`
- Trigger: changes under `AmethystSwiftUI/**` (or manual dispatch)
- Output artifacts:
  - `AmethystSwiftUI-simulator.app.zip`
  - `AmethystSwiftUI-device-unsigned.app.zip`

## Migration strategy
1. Keep runtime core in current native layer.
2. Replace UI flows by connecting this app to real bridge calls.
3. Validate parity screen-by-screen, then retire old UIKit screens.
