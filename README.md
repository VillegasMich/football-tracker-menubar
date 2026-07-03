# football-menubar-app

A macOS menu bar app built with SwiftUI's `MenuBarExtra`.

## Requirements
- macOS 13 or later
- Swift 6 toolchain (no full Xcode required)

## Run (development)

```sh
swift run
```

A ⚽ icon appears in the menu bar. The app has no Dock icon (it runs as an
`.accessory` app). Use **Quit** in the menu to stop it, or press `Ctrl-C` in
the terminal that launched it.

## Build a standalone app

To get an app you can launch and leave running (no terminal attached), build
an `.app` bundle:

```sh
./build.sh
```

This produces `FootballMenuBar.app` in the project root. Launch it with:

```sh
open FootballMenuBar.app
```

The ⚽ icon stays in the menu bar and the app keeps running even after you
close the terminal. Use **Quit** in the menu to stop it.

### Install it (optional)

Move the bundle into `/Applications` so it shows up in Spotlight/Launchpad:

```sh
mv FootballMenuBar.app /Applications/
open /Applications/FootballMenuBar.app
```

To launch it automatically at login, add it under
**System Settings → General → Login Items → Open at Login**.

## Project layout

| File | Purpose |
| --- | --- |
| `Sources/FootballMenuBar/FootballMenuBarApp.swift` | App entry point + `AppDelegate` that hides the Dock icon |
| `Sources/FootballMenuBar/MenuContent.swift` | The dropdown menu items — start editing here |

## Next steps
- Swap `.menuBarExtraStyle(.menu)` for `.window` to show a full SwiftUI popover.
- Change the `systemImage: "soccerball"` to any [SF Symbol](https://developer.apple.com/sf-symbols/).
