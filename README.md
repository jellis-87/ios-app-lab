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

## Live sessions (tap the app from your browser)

A live session runs the app in the iPhone Simulator on a GitHub Mac and streams the screen to a web page. Click to tap, drag to swipe, and type into text fields.

1. Add a repository secret named `LIVE_PASSWORD` (at least 8 characters). The viewer asks for it.
2. Run the **Live session (Tasks)** workflow (Actions tab → Run workflow, or `gh workflow run live-tasks.yml`).
3. After 5–10 minutes the run shows **Live session is ready** with a `trycloudflare.com` link. Open it and enter the password.
4. Press **End session** when you're done, or it closes after the time you chose.

Expect a few frames per second and about a second of delay. The link is public in the run log, so the password is what keeps others out. A session ends when the run ends, and the link stops working.

### Using it for another app

The tooling in `live/` and `.github/workflows/live-session.yml` is reusable. In the other app's repository, add a `LIVE_PASSWORD` secret and a workflow like this:

```yaml
name: Live session
on:
  workflow_dispatch:
    inputs:
      minutes: { type: number, default: 60 }
jobs:
  live:
    uses: jellis-87/ios-app-lab/.github/workflows/live-session.yml@main
    with:
      project-dir: ios          # folder with project.yml / the .xcodeproj
      project: MyApp            # Xcode project name
      scheme: MyApp
      bundle-id: com.example.MyApp
      minutes: ${{ inputs.minutes }}
    secrets: inherit
```

How it works: `live/driver` is a UI test that launches the app and runs a small HTTP server inside the simulator, turning requests into taps, swipes and typing with Apple's XCUITest. `live/viewer/server.py` serves the page, checks the password and relays requests. A free Cloudflare quick tunnel makes it reachable from your browser.

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
