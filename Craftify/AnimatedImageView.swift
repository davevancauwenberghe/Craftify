//
//  AnimatedImageView.swift
//  Craftify
//
//  Native PNG and animated GIF rendering.
//

import ImageIO
import SwiftUI
import UIKit

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
}

struct AnimatedImageView: View {
    let data: Data

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        AnimatedUIImageView(
            data: data,
            animates: !reduceMotion
        )
    }
}

private struct AnimatedUIImageView: UIViewRepresentable {
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

        context.coordinator.data = data
        context.coordinator.animates = animates
        imageView.image = AnimatedUIImageDecoder.image(
            from: data,
            animates: animates,
            scale: context.environment.displayScale
        )
    }

    final class Coordinator {
        var data: Data?
        var animates = false
    }
}

private enum AnimatedUIImageDecoder {
    static func image(
        from data: Data,
        animates: Bool,
        scale: CGFloat
    ) -> UIImage? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            CGImageSourceGetCount(source) > 0
        else {
            return nil
        }

        let frameCount = CGImageSourceGetCount(source)
        guard animates, frameCount > 1 else {
            guard let frame = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                return UIImage(data: data)
            }
            return UIImage(
                cgImage: frame,
                scale: scale,
                orientation: .up
            )
        }

        var frames: [UIImage] = []
        var totalDuration: TimeInterval = 0
        frames.reserveCapacity(frameCount)

        for index in 0..<frameCount {
            guard let frame = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                continue
            }

            frames.append(
                UIImage(
                    cgImage: frame,
                    scale: scale,
                    orientation: .up
                )
            )
            totalDuration += frameDuration(at: index, in: source)
        }

        guard !frames.isEmpty else { return nil }
        guard frames.count > 1 else { return frames[0] }

        return UIImage.animatedImage(
            with: frames,
            duration: max(totalDuration, 0.1)
        ) ?? frames[0]
    }

    private static func frameDuration(
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

        return duration < 0.02 ? 0.1 : duration
    }
}
