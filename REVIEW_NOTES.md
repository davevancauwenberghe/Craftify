# Craftify compatibility and usability review

Review date: 26 October 2026. App version: 1.0, build 125. Deployment target: iOS/iPadOS 18.0.

## Device and system support

- Removed the full-screen requirement and forced-hidden status bar from both app configurations. iPad windows can resize and participate in multitasking; foreground views use system safe areas. All four orientations remain supported.
- Recipes and Search share `RecipeBrowser`, a native `NavigationSplitView` with an independent detail navigation stack for each tab. Wide windows show the library beside a selected recipe; compact windows show one column. Selection, ingredient navigation, category, and search state stay in the existing view hierarchy during resizing.
- Adopted the native Search tab role and semantic primary-action placement. iOS/iPadOS 27 can arrange system bars, search, and sheets for the current device configuration.
- Added `CraftifyAdaptiveGrid` for chest contents. With the iOS 27.1 SDK and runtime, it queries active vertical reserved division regions, includes their margins, and distributes complete cards on each side of the hinge. Horizontal folds remain part of the scrolling layout. The implementation uses runtime and compiler availability checks; older systems use the existing adaptive grid.
- Replaced custom onboarding and new-recipe modal overlays with system sheets. Chest editors offer medium and large detents at standard text sizes and open at full height for accessibility text sizes. Nested chest creation waits for the editor to dismiss before closing its parent picker. The chest-name keyboard offers Done to finish editing and reveal the remaining controls.

These changes follow Apple's [preparation guidance](https://developer.apple.com/videos/play/tech-talks/111461/) and [adaptive-layout guidance](https://developer.apple.com/videos/play/tech-talks/111463/). Release verification includes the installed iOS 27.1 Duo runtime; results are recorded below.

## Everyday usability

- Put the crafting grid near the top of recipe details by reducing the identity header and using an inline navigation title. At accessibility text sizes, the repeated large title is replaced by a compact output summary.
- Added a counted ingredient list for the selected crafting option. Alternate ingredient sets remain paired with their corresponding output amounts, even when optional sets have gaps or contain only blank slots.
- Ingredient and output taps open a system detail sheet immediately. Craftable ingredients link to their own recipes; closing the sheet returns to the previous layout.
- Kept the required utility's name visible in the collapsed notes disclosure.
- Gave accessibility recipe rows their full text width, with the image above the name instead of beside it.
- Made crafting cells respond to available container width, retaining a minimum 44-point touch target. Category and option buttons also have at least 44-point heights.
- Reduced card borders, shadows, and background decoration. The default accent is darker in light mode, while dark mode retains its brighter green. Recipe rows are denser; recommendations start collapsed for new preferences and stay out of category-filtered results. Existing expansion preferences remain respected.
- Removed repeated hero cards from More and the chest library so the sync action, tools, and saved content appear sooner.
- Recipe sync now uses a small, non-blocking progress banner. Downloaded recipes stay available while the update runs.
- New-recipe announcements list readable names and categories; their Explore action returns to the Recipes library.
- Preserved native tab announcements instead of posting a second VoiceOver announcement for every tab change.

## iPad layout follow-up

Raised after the first iPad pass: the sidebar button sat on its own row above the large "Craftify" title, system-drawn controls were a different green from the app, and widths differed across the Chests screens.

- **Library column sizing.** The Recipes and Search libraries always live in a 300–460 pt sidebar (or fill a compact window), but their grids asked for 320 pt minimum columns and padded by the window's size class, so rows could overflow the column on iPad. They now use one flexible column and a fixed `CraftifyLayout.sidebarPadding`.
- **Sidebar title.** `RecipeBrowser` reads the window's size class outside the split view's columns and passes it down as `craftifyShowsSidebar`. In a wide window the library uses an inline title beside the sidebar button; compact windows keep the large title. The title is set once, by `craftifyLibraryTitle`.
- **System accent.** `AccentColor` in the asset catalog was still the old `#00AA00` in both appearances, while the in-app default is `#168238` in light mode. UIKit-drawn chrome takes its tint from the asset. Both now use the same light and dark values.
- **Chests widths.** `ChestDetailView` used a hardcoded 1200 pt cap and 16 pt padding; every other page uses `craftifyContentWidth` (1180 pt) and `pagePadding`. It now matches, and the chest list rows end at the same width. The header's capacity bar and name field no longer stop at 400 pt beside the icon, and card cells no longer stop at 220 pt, which left them narrower than the header in narrow windows.
- **Chest sheets.** The editor, the add-to-chest picker, the nested editor, and the tutorial now share `craftifyFormSheet()` (form-sized on iPad). The editor and picker previously used full-page sheets while the tutorial used a form sheet.
- Chest cards use a plain canvas fill instead of rendering a full `AppBackground` per card (up to 54 per chest).

These edits were made without a device or simulator. CI compiles them and runs the existing 22 tests on iPhone and iPad, but none of those tests measure layout, so the iPad appearance still needs a manual look: Recipes and Search with the sidebar open and in narrow windows, a filled chest at several window widths, the chest sheets on iPad, and the sidebar button and tab bar in both appearances.

## Bugs fixed

| Area | Previous behavior | Corrected behavior |
| --- | --- | --- |
| Search | Only primary ingredients matched. Whitespace interfered, and losing search focus cleared the query. | All four alternate ingredient fields are searched; surrounding whitespace is trimmed and matching handles case and diacritics. Query and scope survive opening recipes. |
| Chest clearing | Removing the iCloud key left other devices' in-memory collections intact. | Save an explicit empty collection and mirror it locally, so other devices observe the clear. |
| Existing favorites | Pre-chest favorites had no migration into the new collection model. | Migrate them into one or more 54-slot Favorites chests without requiring the recipe catalog to be loaded. |
| Offline collections | Chests and recent history depended on the ubiquitous store being available. | Mirror both in local defaults and restore them when the cloud store has no value. |
| Recent history | An empty or temporarily incomplete library discarded saved history entries. | Retain the names; the search UI resolves the entries available in the current library. |
| Chest decoding | Synthesized decoding bypassed the initializer's capacity limit and allowed duplicate recipe IDs. | Decode through the normalizing initializer, remove duplicates, and enforce capacity. |
| Chest usage | A partially available recipe library made occupied slots appear empty. | Show the number of stored IDs when reporting capacity. |
| Report refresh | A fetch during the cooldown returned an empty list and cleared My Reports. | Return the last fetched reports, updating that cache on deletion. |
| Sync status | A previous success timestamp hid current progress or failure. | Report current syncing or failure before the previous success time; restore the cooldown when More reappears. |
| Concurrent recipe fetches | Startup and Search could start overlapping downloads and compete over loading state. | Share the current loading task. Clearing the cache cancels and invalidates it. |
| Partial CloudKit queries | Failed individual records could silently replace the offline catalog with a partial result. | Propagate record failures and retain the existing catalog. Recipe records with invalid numeric IDs no longer all become ID zero. |
| Local recipe writes | An interrupted cache write could leave a damaged recipe file. | Write the cache atomically. |
| Image preparation | In-flight prefetches were counted as finished; failed refreshes could suppress normal retries. | Explicit preparation waits for current prefetches, failures remain retryable, and invalidated tasks cannot clear a newer generation's loading state. |
| Local-only startup | Constructing the image store immediately opened CloudKit, including unsigned test launches. | Create the database lazily when remote work is actually requested. |
| Chest editor sheets | Large text could open in a medium-height sheet; saving a new chest requested dismissal of both nested sheets together. | Accessibility sheets open at full height and parent dismissal waits for the editor to finish closing. |
| Help tour | Returning users could be blocked from the guide by an unrelated sync error. | First-launch loading gates apply to first launch; the returning-user guide remains available. Initial loading content can scroll in short windows and at large text sizes. |

## Verification

The implementation was compiled with Xcode 27.1 / Swift 6.4 and an iOS 27.1 SDK while retaining the iOS 18 deployment target. Tests use an isolated key-value store and defaults. UI tests load a Debug-only offline fixture; Release builds omit the fixture.

| Configuration | Result |
| --- | --- |
| iPhone Duo, iOS 27.1 | 16 unit tests + 6 UI tests passed |
| iPhone 18 Pro, iOS 27.0 | 16 unit tests + 6 UI tests passed |
| iPad Pro 13-inch (M5), iPadOS 27.0 | 16 unit tests + 6 UI tests passed |
| iPhone 16 Pro Max, iOS 18.0 | 16 unit tests + 6 UI tests passed |
| Release, generic iOS device destination | Build passed with signing disabled |
| Release archive, build 125 | Automatic signing succeeded; signature verification passed |
| Project/Info property lists, workflow YAML, whitespace checks | Passed |

The UI suite exercises appearance settings, alternate-ingredient search with query preservation, the first-launch tour, large-text chest creation, ingredient-to-recipe navigation across rotation, and saving into an existing chest. Screenshots were exported and visually inspected. After the final accessibility row adjustment, focused large-text checks passed on both iPhone and iPad, and the iPad rotation/ingredient-navigation check also passed. The Release build was repeated successfully after that refinement.

Xcode emitted SDK build-number/debugger diagnostic messages during test startup, but the completed test bundles report no failures or runtime warnings. The Release product reports build 125, deployment target 18.0, all four orientations, and no full-screen or hidden-status-bar requirement. The test-fixture symbols are absent from the Release executable.

The installed iOS 27.1 runtime supports iPhone Duo only, so iPad checks use iPadOS 27.0. The first Duo run exposed test assumptions about horizontal navigation bars and screen aspect ratios; the checks now locate the native Back control independently of bar placement. XCTest's orientation setting did not rotate the active Duo display reliably, so actual display rotation was checked separately with the simulator helper described below.

Manual Duo checks covered the closed cover display, fully open inner display, partially folded inner display, inner-display portrait and landscape, and closing back to the cover in landscape. A five-recipe chest retained its selection and occupied-slot count across those transitions. Partially folding in landscape introduced a visible gap between complete cards on each side of the vertical hinge; portrait retained a continuous scrolling grid. Screenshots were captured from the active display and visually inspected. The helper could read back the active screen, dimensions, and orientation, but this Xcode version did not provide its hinge-angle readback, so the requested partial-fold angle is not treated as a measured result.

Final iPad checking caught an intermittent save-tap failure with the name keyboard active; an unchanged retry passed. The chest-name field now provides Done, and the regression finishes text entry before tapping Save, waits for both sheets to close, and confirms that the created chest appears in the library.

After the keyboard refinement, the complete 22-test iPad suite passed again with no runtime warnings.

Live CloudKit service behavior, simultaneous writes from two signed-in devices, VoiceOver gestures, alternate-icon changes, and system Split View on either side of Duo require additional device/account checks. Automated storage tests simulate shared values; they do not establish that a live iCloud account synchronized successfully.

CI now triggers for unit/UI test changes and runs the regression suite on available iPhone and iPad simulators. It uses GitHub's [Xcode 27 runner](https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available/): the previous macOS 26 image selected Xcode 26.6, which could not open project format 110. README and in-app release notes describe the updated behavior and development workflow. Existing release-note entries are retained.

Local review artifacts are retained at `/private/tmp/CraftifyReview/`. They include iPhone crafting, search, dark appearance, and large-text screens, iPad landscape and large-text screens, and five Duo pose screenshots. Successful complete test bundles include `/private/tmp/Craftify125Duo271ReleaseChecks.xcresult`, `/private/tmp/CraftifyFinaliPhone27.xcresult`, `/private/tmp/Craftify125iPadFinalRegression.xcresult`, and `/private/tmp/CraftifyFinaliOS18.xcresult`; focused results are in `/private/tmp/CraftifyVisualiPhone.xcresult` and `/private/tmp/CraftifyVisualiPad.xcresult`. Release archives and deployment artifacts are under `/private/tmp/Craftify125Release/`. These temporary artifacts are not part of the Git repository.

Duo pose verification uses a reviewed temporary copy of [duoctl](https://github.com/skarol/duoctl), pinned at `efd5e3d62fd85f555057b429deafcc9c81123454`. It sends simulator-only HID events and reads back the active display. Its cache and source stay outside the app and repository; no private simulator APIs are included in the release app.
