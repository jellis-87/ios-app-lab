# TasksApp

A SwiftUI iOS app that is built and tested on GitHub's macOS machines, so it can be developed from Windows.

## How it works

Every push runs [`.github/workflows/ios.yml`](.github/workflows/ios.yml) on a macOS runner with Xcode:

1. XcodeGen turns `project.yml` into `TasksApp.xcodeproj`.
2. `xcodebuild test` compiles the app with Apple's real Swift compiler and runs the unit tests in an iPhone simulator.
3. The app is installed and launched in the simulator, and screenshots are saved in light and dark mode.

Each run uploads three artifacts:

| Artifact | Contents |
| --- | --- |
| `screenshots` | `light.png` and `dark.png` from the simulator |
| `simulator-app` | A zipped simulator build of the app (works with simulator streaming services such as Appetize.io) |
| `build-log` | The full `xcodebuild` output |

Compiler errors also appear in the run's summary page.

## Layout

```
project.yml          Xcode project spec (targets, bundle ID, iOS version)
Sources/             App code
Tests/               Unit tests (XCTest)
.github/workflows/   CI build
```

Add new `.swift` files to `Sources/` and they are picked up automatically.

## Useful commands

```bash
gh run watch                       # follow the latest build
gh run view --log-failed           # show what broke
gh run download -n screenshots     # fetch the simulator screenshots
```

## Limits

- The app is not code-signed, so this produces simulator builds only. Installing on a real iPhone or uploading to the App Store needs an Apple Developer account and signing set up in the workflow.
- macOS runner minutes are free for public repositories. Private repositories use the account's monthly allowance, and macOS minutes count at a higher rate.
