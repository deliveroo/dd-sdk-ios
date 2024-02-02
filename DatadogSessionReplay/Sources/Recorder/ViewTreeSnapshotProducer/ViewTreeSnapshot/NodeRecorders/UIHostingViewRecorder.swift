/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import UIKit
import SwiftUI

#if canImport(CustomDump)
import CustomDump
#endif

internal class UIHostingViewRecorder: NodeRecorder {
    let identifier = UUID()

    /// An option for overriding default semantics from parent recorder.
    var semanticsOverride: (UIView, ViewAttributes) -> NodeSemantics?
    var textObfuscator: (ViewTreeRecordingContext) -> TextObfuscating

    let cls: AnyClass? = NSClassFromString("_UIHostingView")

    init(
        semanticsOverride: @escaping (UIView, ViewAttributes) -> NodeSemantics? = { _, _ in nil },
        textObfuscator: @escaping (ViewTreeRecordingContext) -> TextObfuscating = { context in
            return context.recorder.privacy.staticTextObfuscator
        }
    ) {
        self.semanticsOverride = semanticsOverride
        self.textObfuscator = textObfuscator
    }

    func semantics(of view: UIView, with attributes: ViewAttributes, in context: ViewTreeRecordingContext) -> NodeSemantics? {
        guard String(describing: type(of: view)).hasPrefix("_UIHostingView") else {
            return nil
        }

#if canImport(CustomDump)
//        customDump(view)
#endif

        do {
            let host = try _UIHostingView(reflecting: view)

            let builder = UIHostingUIWireframesBuilder(
                renderer: host.renderer.renderer,
                textObfuscator: textObfuscator(context),
                fontScalingEnabled: false,
                referential: UIHostingUIWireframesBuilder.Referential(attributes.frame)
            )

            let node = Node(viewAttributes: attributes, wireframesBuilder: builder)
            return SpecificElement(subtreeStrategy: .record, nodes: [node])
        } catch {
            print(error)
            return nil
        }
    }
}

internal struct UIHostingUIWireframesBuilder: NodeWireframesBuilder {
    internal struct Referential {
        let frame: CGRect
    }

    let renderer: DisplayList.ViewUpdater
    /// Text obfuscator for masking text.
    let textObfuscator: TextObfuscating
    /// Flag that determines if font should be scaled
    var fontScalingEnabled: Bool

    let referential: Referential

    var wireframeRect: CGRect {
        referential.frame
    }

    func buildWireframes(with builder: WireframesBuilder) -> [SRWireframe] {
//        print("######## NEW BUILD ########")
        return buildWireframes(items: renderer.lastList.items, referential: referential, builder: builder)
    }

    private func buildWireframes(items: [DisplayList.Item], referential: Referential, builder: WireframesBuilder) -> [SRWireframe] {
        items.reduce([]) { wireframes, item in
            switch item.value {
//            case .none:
//                return nil
            case let .effect(effect, list):
                return wireframes + effectWireframe(item: item, effect: effect, list: list, referential: referential, builder: builder)
            case .content(let content):
                return wireframes + contentWireframe(item: item, content: content, referential: referential, builder: builder)
            case .unknown:
                return wireframes
            }
        }
    }

    private func contentWireframe(item: DisplayList.Item, content: DisplayList.Content, referential: Referential, builder: WireframesBuilder) -> SRWireframe? {
//        print("######## Seed:", content.seed.value)
        let info = renderer.viewCache.map[DisplayList.ViewUpdater.ViewCache.Key(id: DisplayList.Index.ID(identity: item.identity))]

        switch content.value {
        case let .shape(_, paint, _):
            return builder.createShapeWireframe(
                id: Int64(content.seed.value),
                frame: referential.convert(frame: item.frame),
                backgroundColor: CGColor(
                    red: CGFloat(paint.paint.linearRed),
                    green: CGFloat(paint.paint.linearGreen),
                    blue: CGFloat(paint.paint.linearBlue),
                    alpha: CGFloat(paint.paint.opacity)
                ),
                opacity: CGFloat(paint.paint.opacity)
            )
        case let .text(view, _):
            let storage = view.text.storage
            let style = storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
            let foregroundColor = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
            let font = storage.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            return builder.createTextWireframe(
                id: Int64(content.seed.value),
                frame: referential.convert(frame: item.frame),
                text: textObfuscator.mask(text: storage.string),
                textAlignment: style.map { .init(systemTextAlignment: $0.alignment) },
                textColor: foregroundColor?.cgColor,
                font: font,
                fontScalingEnabled: fontScalingEnabled
            )
        case .color:
//            return nil
            return builder.createShapeWireframe(
                id: Int64(content.seed.value),
                frame: referential.convert(frame: item.frame),
                clip: nil,
                borderColor: info?.borderColor,
                borderWidth: info?.borderWidth,
                backgroundColor: info?.backgroundColor,
                cornerRadius: info?.cornerRadius,
                opacity: info?.alpha
            )
//            return builder.createShapeWireframe(
//                id: Int64(content.seed.value),
//                frame: referential.convert(frame: item.frame),
//                backgroundColor: CGColor(
//                    red: CGFloat(color.linearRed),
//                    green: CGFloat(color.linearGreen),
//                    blue: CGFloat(color.linearBlue),
//                    alpha: CGFloat(color.opacity)
//                ),
//                opacity: CGFloat(color.opacity)
//            )
        case .platformView:
            return nil // Should be recorder by UIKit recorder
        case .unknown:
            return nil // Need a placeholder

        }
    }

    private func contentWireframe(item: DisplayList.Item, content: DisplayList.Content, referential: Referential, builder: WireframesBuilder) -> [SRWireframe] {
        contentWireframe(item: item, content: content, referential: referential, builder: builder).map { [$0] } ?? []
    }

    func effectWireframe(item: DisplayList.Item, effect: DisplayList.Effect, list: DisplayList, referential: Referential, builder: WireframesBuilder) -> [SRWireframe] {
        buildWireframes(
            items: list.items,
            referential: Referential(convert: item.frame, to: referential),
            builder: builder
        )
    }
}

extension UIHostingUIWireframesBuilder.Referential {
    init(_ frame: CGRect) {
        self.frame = frame
    }

    init(convert frame: CGRect, to referential: Self) {
        self.frame = referential.convert(frame: frame)
    }

    func convert(frame: CGRect) -> CGRect {
        frame.offsetBy(
            dx: self.frame.origin.x,
            dy: self.frame.origin.y
        )
    }
}
