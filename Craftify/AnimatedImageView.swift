//
//  AnimatedImageView.swift
//  Craftify
//
//  Shared PNG and animated GIF rendering for macOS, iOS, and iPadOS.
//

import ImageIO
import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum CraftImageData {
    static func isValidImage(_ data: Data) -> Bool {
        guard
            !data.isEmpty,
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            CGImageSourceGetCount(source) > 0
        else {
            return false
        }

        return CGImageSourceCreateImageAtIndex(source, 0, nil) != nil
    }

    static func preferredFilenameExtension(
        for data: Data,
        fallback: String = "png"
    ) -> String {
        let cleanedFallback = fallback
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }

        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let typeIdentifier = CGImageSourceGetType(source),
            let detectedExtension = UTType(typeIdentifier as String)?
                .preferredFilenameExtension
        else {
            return cleanedFallback.isEmpty ? "png" : cleanedFallback
        }

        return detectedExtension.lowercased()
    }
}

struct AnimatedImageView: View {
    let data: Data

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PlatformAnimatedImageView(
            data: data,
            animates: !reduceMotion
        )
    }
}

#if canImport(UIKit)
private struct PlatformAnimatedImageView: UIViewRepresentable {
    let data: Data
    let animates: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.backgroundColor = .clear
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.magnificationFilter = .nearest
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        guard
            context.coordinator.data != data ||
            context.coordinator.animates != animates
        else {
            return
        }

        context.coordinator.display(
            data: data,
            animates: animates,
            scale: context.environment.displayScale,
            in: imageView
        )
    }

    static func dismantleUIView(
        _ imageView: UIImageView,
        coordinator: Coordinator
    ) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        var data: Data?
        var animates = false
        private var renderTask: Task<Void, Never>?

        func display(
            data: Data,
            animates: Bool,
            scale: CGFloat,
            in imageView: UIImageView
        ) {
            self.data = data
            self.animates = animates
            renderTask?.cancel()
            imageView.image = nil

            renderTask = Task { @MainActor [weak imageView] in
                guard let descriptor = await AnimatedImagePipeline.shared
                    .descriptor(for: data),
                      !Task.isCancelled
                else {
                    return
                }

                if animates && descriptor.canAnimate {
                    await Self.animate(
                        descriptor: descriptor,
                        data: data,
                        scale: scale,
                        in: imageView
                    )
                } else {
                    guard
                        let frame = await AnimatedImagePipeline.shared.frame(
                            at: 0,
                            for: data
                        ),
                        !Task.isCancelled
                    else {
                        return
                    }

                    imageView?.image = UIImage(
                        cgImage: frame.image,
                        scale: max(scale, 1),
                        orientation: .up
                    )
                }
            }
        }

        func stop() {
            renderTask?.cancel()
            renderTask = nil
        }

        private static func animate(
            descriptor: AnimatedImageDescriptor,
            data: Data,
            scale: CGFloat,
            in imageView: UIImageView?
        ) async {
            var completedLoopCount = 0

            while !Task.isCancelled && (
                descriptor.loopCount == 0 ||
                completedLoopCount < descriptor.loopCount
            ) {
                for index in 0..<descriptor.frameCount {
                    guard
                        !Task.isCancelled,
                        let imageView,
                        let frame = await AnimatedImagePipeline.shared.frame(
                            at: index,
                            for: data
                        )
                    else {
                        return
                    }

                    imageView.image = UIImage(
                        cgImage: frame.image,
                        scale: max(scale, 1),
                        orientation: .up
                    )

                    do {
                        try await Task.sleep(
                            for: .seconds(descriptor.frameDelays[index])
                        )
                    } catch {
                        return
                    }
                }

                completedLoopCount += 1
            }
        }
    }
}

private struct AnimatedImageDescriptor: Sendable {
    let frameCount: Int
    let frameDelays: [TimeInterval]
    let loopCount: Int
    let canAnimate: Bool
}

private final class SendableCGImage: @unchecked Sendable {
    let image: CGImage

    nonisolated init(_ image: CGImage) {
        self.image = image
    }
}

private actor AnimatedImagePipeline {
    static let shared = AnimatedImagePipeline()

    private struct SourceEntry {
        let source: CGImageSource
        let descriptor: AnimatedImageDescriptor
        let cost: Int
        var accessOrder: UInt64
    }

    private struct FrameKey: Hashable, Sendable {
        let data: Data
        let index: Int
    }

    private struct FrameEntry {
        let frame: SendableCGImage
        let cost: Int
        var accessOrder: UInt64
    }

    // CloudKit upload validation permits up to 10 MB of encoded image data. The
    // source cache is intentionally only large enough for one worst-case asset
    // plus a few normal spinner GIFs.
    private let maximumCacheableEncodedBytes = 10 * 1_024 * 1_024
    private let encodedCacheCostLimit = 16 * 1_024 * 1_024

    // Frames are decoded lazily, downsampled, and retained in an explicit LRU.
    // No view ever constructs an unbounded UIImage frame array.
    private let maximumFrameCount = 300
    private let maximumFramePixelDimension = 1_024
    private let maximumDecodedFrameCost = 8 * 1_024 * 1_024
    private let decodedCacheCostLimit = 24 * 1_024 * 1_024

    private var sources: [Data: SourceEntry] = [:]
    private var frames: [FrameKey: FrameEntry] = [:]
    private var encodedCacheCost = 0
    private var decodedCacheCost = 0
    private var accessOrder: UInt64 = 0

    func descriptor(for data: Data) -> AnimatedImageDescriptor? {
        sourceEntry(for: data)?.descriptor
    }

    func frame(at index: Int, for data: Data) -> SendableCGImage? {
        let key = FrameKey(data: data, index: index)
        accessOrder &+= 1

        if var cached = frames[key] {
            cached.accessOrder = accessOrder
            frames[key] = cached
            return cached.frame
        }

        guard
            let sourceEntry = sourceEntry(for: data),
            index >= 0,
            index < sourceEntry.descriptor.frameCount
        else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumFramePixelDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(
            sourceEntry.source,
            index,
            options as CFDictionary
        ) else {
            return nil
        }

        let cost = image.bytesPerRow * image.height
        guard cost <= maximumDecodedFrameCost else {
            return nil
        }

        let frame = SendableCGImage(image)
        guard data.count <= maximumCacheableEncodedBytes else {
            return frame
        }

        frames[key] = FrameEntry(
            frame: frame,
            cost: cost,
            accessOrder: accessOrder
        )
        decodedCacheCost += cost
        trimFrameCache()
        return frame
    }

    private func sourceEntry(for data: Data) -> SourceEntry? {
        accessOrder &+= 1

        if var cached = sources[data] {
            cached.accessOrder = accessOrder
            sources[data] = cached
            return cached
        }

        guard
            !data.isEmpty,
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            CGImageSourceGetCount(source) > 0
        else {
            return nil
        }

        let descriptor = makeDescriptor(for: source)
        let entry = SourceEntry(
            source: source,
            descriptor: descriptor,
            cost: data.count,
            accessOrder: accessOrder
        )

        guard data.count <= maximumCacheableEncodedBytes else {
            return entry
        }

        sources[data] = entry
        encodedCacheCost += entry.cost
        trimSourceCache(protecting: data)
        return entry
    }

    private func makeDescriptor(
        for source: CGImageSource
    ) -> AnimatedImageDescriptor {
        let sourceFrameCount = CGImageSourceGetCount(source)
        let isAnimatedGIF: Bool
        if let typeIdentifier = CGImageSourceGetType(source) {
            isAnimatedGIF = UTType(typeIdentifier as String) == .gif &&
                sourceFrameCount > 1
        } else {
            isAnimatedGIF = false
        }
        let canAnimate = isAnimatedGIF &&
            sourceFrameCount <= maximumFrameCount

        let frameCount = isAnimatedGIF ? sourceFrameCount : 1
        let delays = canAnimate
            ? (0..<frameCount).map { frameDuration(at: $0, in: source) }
            : []

        return AnimatedImageDescriptor(
            frameCount: frameCount,
            frameDelays: delays,
            loopCount: canAnimate ? loopCount(in: source) : 1,
            canAnimate: canAnimate
        )
    }

    private func frameDuration(
        at index: Int,
        in source: CGImageSource
    ) -> TimeInterval {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(
                source,
                index,
                nil
            ) as? [CFString: Any],
            let gifProperties = properties[
                kCGImagePropertyGIFDictionary
            ] as? [CFString: Any]
        else {
            return 0.1
        }

        let unclamped = gifProperties[
            kCGImagePropertyGIFUnclampedDelayTime
        ] as? NSNumber
        let clamped = gifProperties[
            kCGImagePropertyGIFDelayTime
        ] as? NSNumber
        let duration = unclamped?.doubleValue ?? clamped?.doubleValue ?? 0.1

        guard duration.isFinite, duration > 0 else {
            return 0.1
        }

        // Avoid pathological zero-delay busy loops while retaining each frame's
        // distinct source timing.
        return min(max(duration, 0.02), 60)
    }

    private func loopCount(in source: CGImageSource) -> Int {
        guard
            let properties = CGImageSourceCopyProperties(
                source,
                nil
            ) as? [CFString: Any],
            let gifProperties = properties[
                kCGImagePropertyGIFDictionary
            ] as? [CFString: Any],
            let count = gifProperties[
                kCGImagePropertyGIFLoopCount
            ] as? NSNumber
        else {
            return 0
        }

        return max(count.intValue, 0)
    }

    private func trimSourceCache(protecting protectedData: Data) {
        while encodedCacheCost > encodedCacheCostLimit {
            guard let victim = sources
                .filter({ $0.key != protectedData })
                .min(by: { $0.value.accessOrder < $1.value.accessOrder })
            else {
                break
            }

            if let removed = sources.removeValue(forKey: victim.key) {
                encodedCacheCost -= removed.cost
                removeFrames(for: victim.key)
            }
        }
    }

    private func trimFrameCache() {
        while decodedCacheCost > decodedCacheCostLimit,
              let victim = frames.min(
                by: { $0.value.accessOrder < $1.value.accessOrder }
              ) {
            if let removed = frames.removeValue(forKey: victim.key) {
                decodedCacheCost -= removed.cost
            }
        }
    }

    private func removeFrames(for data: Data) {
        let matchingKeys = frames.keys.filter { $0.data == data }
        for key in matchingKeys {
            if let removed = frames.removeValue(forKey: key) {
                decodedCacheCost -= removed.cost
            }
        }
    }
}
#elseif canImport(AppKit)
private struct PlatformAnimatedImageView: NSViewRepresentable {
    let data: Data
    let animates: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = animates
        imageView.wantsLayer = true
        imageView.layer?.magnificationFilter = .nearest
        return imageView
    }

    func updateNSView(_ imageView: NSImageView, context: Context) {
        guard
            context.coordinator.data != data ||
            context.coordinator.animates != animates
        else {
            return
        }

        context.coordinator.data = data
        context.coordinator.animates = animates
        imageView.animates = animates
        imageView.image = NSImage(data: data)
    }

    final class Coordinator {
        var data: Data?
        var animates = false
    }
}
#endif
