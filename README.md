# Craftify for Minecraft

[![Craftify iOS CI](https://github.com/davevancauwenberghe/Craftify/actions/workflows/ios.yml/badge.svg?branch=main)](https://github.com/davevancauwenberghe/Craftify/actions/workflows/ios.yml)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg?logo=swift)
![Xcode](https://img.shields.io/badge/Xcode-26.3-blue.svg)
![Platform](https://img.shields.io/badge/Platform-iOS%2018.0%2B%20%7C%20iPadOS%2018.0%2B-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg?link=https://github.com/davevancauwenberghe/Craftify/blob/main/LICENSE)
![GitHub Stars](https://img.shields.io/github/stars/davevancauwenberghe/Craftify)

## Crafting recipes for Minecraft

Craftify is a sleek iOS app designed for Minecraft players to browse, search, and manage crafting recipes with ease. Built with SwiftUI and CloudKit, Craftify offers a seamless experience for discovering recipes, saving favorites, and personalizing the app with alternate icons—all optimized for accessibility and performance.

---

## Description

[Craftify](https://www.davevancauwenberghe.be/projects/craftify-for-minecraft/) is the ultimate companion app for Minecraft enthusiasts looking to master crafting recipes. Whether you're a seasoned player or a beginner, Craftify provides an intuitive interface to explore hundreds of recipes, filter by category, save your favorites, and sync them across devices using CloudKit. With features like alternate app icons, dark mode support, and full VoiceOver accessibility, Craftify ensures a personalized and inclusive experience for all users.

### Key Features

- **Browse Recipes**: Explore a comprehensive list of Minecraft crafting recipes, organized alphabetically and by category.
- **Search and Filter**: Quickly find recipes by name, category, or ingredient using the search bar.
- **Favorites**: Save your go-to recipes for easy access and sync them across devices with CloudKit.
- **Alternate App Icons**: Customize the app’s look with multiple icon options (Default, Alternate 1, Alternate 2).
- **Accessibility**: Fully optimized for VoiceOver, Dynamic Type, and other iOS accessibility features.
- **Light/Dark Mode**: Seamlessly adapts to your device’s appearance settings.
- **CloudKit Syncing**: Keep your favorites in sync across all your devices.
- **Haptic Feedback**: Enjoy tactile feedback for a more engaging experience.

### Craftify interface

Craftify uses a shared SwiftUI design layer (`CraftifyDesignSystem.swift`) for its crafting-grid backgrounds, adaptive content widths, cards, status badges, empty states, and headers. Screens keep native navigation and controls so iOS and iPadOS 26 receive Liquid Glass automatically, while iOS and iPadOS 18–25 retain semantic system materials. Content layouts adapt from a focused single column on iPhone to centered, multi-column grids on wider iPad windows, with dedicated layouts for accessibility Dynamic Type sizes.

#### Disclaimer

Craftify for Minecraft ("Craftify") is not an official Minecraft product, it is not approved or associated with Mojang or Microsoft.

![AppIcon](https://github.com/davevancauwenberghe/Craftify/blob/main/Craftify/Assets.xcassets/AppIcon.appiconset/AppIcon.png)
