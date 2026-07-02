# football-menubar-app

A macOS menu bar app built with SwiftUI's `MenuBarExtra`.

## Requirements
- macOS 13 or later
- Swift 6 toolchain (no full Xcode required)

## Run

```sh
swift run
```

A ⚽ icon appears in the menu bar. The app has no Dock icon (it runs as an
`.accessory` app). Use **Quit** in the menu to stop it, or press `Ctrl-C` in
the terminal that launched it.

## Project layout

| File | Purpose |
| --- | --- |
| `Sources/FootballMenuBar/FootballMenuBarApp.swift` | App entry point + `AppDelegate` that hides the Dock icon |
| `Sources/FootballMenuBar/MenuContent.swift` | The dropdown menu items — start editing here |

## Next steps
- Swap `.menuBarExtraStyle(.menu)` for `.window` to show a full SwiftUI popover.
- Change the `systemImage: "soccerball"` to any [SF Symbol](https://developer.apple.com/sf-symbols/).
