# Agent Notes

## Project Workflow

- Use XcodeGen as the source of truth for the Xcode project. Update `project.yml`, then run `xcodegen generate` when target membership or project settings change.
- Keep reusable parsing, telemetry, layout, and persistence code in `Packages/ProbeCore`; keep the AppKit app in `Apps/Probe` thin.
- Prefer focused changes that match the existing AppKit and Swift Package patterns.
- Do not revert unrelated local changes. This repository is often worked on interactively.

## Verification

- Run `Scripts/lint-swift.sh` for Swift syntax linting.
- Run `swift test` from `Packages/ProbeCore` when core package behavior changes.
- Run `xcodebuild -scheme Probe -derivedDataPath .derivedData test` when app UI, settings, screenshots, or integration behavior changes.
- After each implementation iteration, install the latest app build to `/Applications/Probe.app` so local manual testing uses the current version. Request approval when installation requires elevated filesystem access.

## Screenshots

- When work affects visible UI, settings panes, icons, HUD rendering, themes, or user-requested visual behavior, use the screenshot tests to produce fresh images.
- Show the generated screenshots in the conversation so the user can see ongoing work, requested changes, and new features without needing to run the app locally.
- Before sharing a screenshot, verify it is the newly generated test output for the current change, not the user-provided reference image or a stale screenshot. Check the file path and modification time when in doubt.
- Screenshot test output is written under `.derivedData/TestScreenshots/`.
