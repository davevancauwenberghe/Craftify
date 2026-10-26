# Craftify for Minecraft

[![Craftify iOS CI](https://github.com/davevancauwenberghe/Craftify/actions/workflows/ios.yml/badge.svg?branch=main)](https://github.com/davevancauwenberghe/Craftify/actions/workflows/ios.yml)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg?logo=swift)
![Xcode](https://img.shields.io/badge/Xcode-27.1-blue.svg)
![Platform](https://img.shields.io/badge/Platform-iOS%2018.0%2B%20%7C%20iPadOS%2018.0%2B-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg?link=https://github.com/davevancauwenberghe/Craftify/blob/main/LICENSE)
![GitHub Stars](https://img.shields.io/github/stars/davevancauwenberghe/Craftify)

## Crafting recipes for Minecraft

Craftify is a sleek iOS app designed for Minecraft players to browse, search, and manage crafting recipes with ease. Built with SwiftUI and CloudKit, Craftify offers a seamless experience for discovering recipes, saving recipes in chests, and personalizing the app with alternate icons—all optimized for accessibility and performance.

---

## Description

[Craftify](https://www.davevancauwenberghe.be/projects/craftify-for-minecraft/) is the ultimate companion app for Minecraft enthusiasts looking to master crafting recipes. Whether you're a seasoned player or a beginner, Craftify provides an intuitive interface to explore hundreds of recipes, filter by category, organize recipes into chests, and sync them across devices using iCloud. With features like alternate app icons, dark mode support, and full VoiceOver accessibility, Craftify ensures a personalized and inclusive experience for all users.

### Key Features

- **Browse Recipes**: Explore a comprehensive list of Minecraft crafting recipes, organized alphabetically and by category.
- **Search and Filter**: Search by name or ingredient and filter the library by category.
- **Chests**: Organize recipes into named 27-slot or 54-slot collections, with a local backup and iCloud sync. Favorites from older versions migrate into chests.
- **Alternate App Icons**: Customize the app’s look with multiple icon options (Default, Alternate 1, Alternate 2).
- **Accessibility**: Fully optimized for VoiceOver, Dynamic Type, and other iOS accessibility features.
- **Light/Dark Mode**: Seamlessly adapts to your device’s appearance settings.
- **Offline Recipe Book**: Download recipes and images for use while playing. Refreshes keep the current book available.
- **Adaptive Navigation**: Browse recipes beside their crafting layout on wide iPhone Duo and iPad windows, with compact navigation on smaller screens.
- **CloudKit Syncing**: Keep your recipe library current; chests and recent searches sync through iCloud key-value storage.
- **Haptic Feedback**: Enjoy tactile feedback for a more engaging experience.

### Craftify interface

Craftify uses a shared SwiftUI design layer (`CraftifyDesignSystem.swift`) with restrained backgrounds, readable cards, native navigation, and Dynamic Type layouts. Recipes and Search use a persistent `NavigationSplitView`: the library and selected recipe share wide windows, and collapse to a single navigation flow in compact windows. Search includes all alternate ingredients, and opening a recipe preserves the query.

The crafting grid appears near the top of recipe details, followed by a counted ingredient list and crafting notes. Tapping a grid item opens a system sheet; crafting options remain paired with their output quantities. Recipe refreshes show a small progress banner while downloaded content stays available.

### iPhone Duo and iOS/iPadOS 27

Build with **Xcode 27.1** to enable the latest system navigation, tab, sheet, and safe-area behavior. Craftify supports every orientation, resizable iPad windows, and iPhone Duo without device-model or screen-size checks. On iOS 27.1, chest grids query active reserved division regions and leave space for the hinge and its margins. These APIs are guarded by compiler and OS availability; the deployment target remains **iOS/iPadOS 18.0**.

Implementation follows Apple's [resizability guidance](https://developer.apple.com/videos/play/tech-talks/111461/) and [adaptive layout guidance for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/).

### Development and verification

Open `Craftify.xcodeproj` and choose the shared **Craftify** scheme. Run the unit and UI tests on available iPhone and iPad simulators. The UI suite uses a deterministic offline library through a Debug-only `-ui-testing` launch argument, so it does not depend on a live CloudKit account or modify production collections. This fixture is omitted from Release builds.

```sh
xcodebuild test -project Craftify.xcodeproj -scheme Craftify \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

For Duo validation, use a compatible **iOS 27.1 or later runtime** in Device Hub. Check the outer display, unfolded and partially folded inner display, both orientations, and Split View on either side. Keep a recipe and an alternate-ingredient search open while changing poses. Also check narrow iPad windows, the largest accessibility text size, VoiceOver, Reduce Motion, and Reduce Transparency. The [review notes](REVIEW_NOTES.md) record which checks were actually run.

#### Disclaimer

Craftify for Minecraft ("Craftify") is not an official Minecraft product, it is not approved or associated with Mojang or Microsoft.

![AppIcon](https://github.com/davevancauwenberghe/Craftify/blob/main/Craftify/Assets.xcassets/AppIcon.appiconset/AppIcon.png)
