# Swift Integration Notes

This project currently builds native code through CMake and Objective-C.

When you are ready to wire Swift UI in:

1. Add Swift files from `NativesSwift/` into the native target.
2. Ensure a module is generated (for Objective-C to access `@objc` Swift types).
3. Use Objective-C generated header:
   - `#import "<ProductModuleName>-Swift.h"`
4. Replace menu controller creation point with `SwiftMenuFactory.makeMenuController(...)`.
5. Keep navigation actions in Objective-C until parity is validated.

Do not replace launcher core logic in first migration stage.
