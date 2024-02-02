/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import SwiftUI
import UIKit
import QuartzCore

@available(iOS 13.0, *)
internal struct DisplayList {
    internal struct Identity: Hashable {
        let value: UInt32
    }

    internal struct Seed: Hashable {
        let value: UInt16
    }

    internal struct ViewRenderer {
        let renderer: ViewUpdater
    }

    internal struct ViewUpdater {
        internal struct ViewCache {
            internal struct Key: Hashable {
                let id: Index.ID
            }

            let map: [ViewCache.Key: ViewInfo]
        }

        internal struct ViewInfo {
            /// Original view's `.backgorundColor`.
            let backgroundColor: CGColor?

            /// Original view's `layer.borderColor`.
            let borderColor: CGColor?

            /// Original view's `layer.borderWidth`.
            let borderWidth: CGFloat

            /// Original view's `layer.cornerRadius`.
            let cornerRadius: CGFloat

            /// Original view's `.alpha` (between `0.0` and `1.0`).
            let alpha: CGFloat

            /// Original view's `.isHidden`.
            let isHidden: Bool

            /// Original view's `.intrinsicContentSize`.
            let intrinsicContentSize: CGSize
        }

        let viewCache: ViewCache
        let lastList: DisplayList
    }

    internal struct Index {
        internal struct ID: Hashable {
            let identity: Identity
        }
    }

    internal enum Effect {
        case identify
        case clip(SwiftUI.Path, SwiftUI.FillStyle)
        case unknown
    }

    internal struct Content {
        internal enum Value {
            case shape(SwiftUI.Path, ResolvedPaint, SwiftUI.FillStyle)
            case text(StyledTextContentView, CGSize)
            case platformView
            case color(Color._Resolved)
            case unknown
        }

        let seed: Seed
        let value: Value
    }

    internal struct Item {
        internal enum Value {
            case effect(Effect, DisplayList)
            case content(Content)
            case unknown
        }

        let identity: Identity
        let frame: CGRect
        let value: Value
    }

    let items: [Item]
}

@available(iOS 13.0, *)
extension DisplayList: Reflection {
    init(_ mirror: Mirror) throws {
        items = try mirror.descendant(path: "items")
    }
}

@available(iOS 13.0, *)
extension DisplayList.Identity: Reflection {
    init(_ mirror: Mirror) throws {
        value = try mirror.descendant(path: "value")
    }
}

@available(iOS 13.0, *)
extension DisplayList.Seed: Reflection {
    init(_ mirror: Mirror) throws {
        value = try mirror.descendant(path: "value")
    }
}

@available(iOS 13.0, *)
extension DisplayList.ViewRenderer: Reflection {
    init(_ mirror: Mirror) throws {
        renderer = try mirror.descendant(path: "renderer")
    }
}

@available(iOS 13.0, *)
extension DisplayList.ViewUpdater: Reflection {
    init(_ mirror: Mirror) throws {
        viewCache = try mirror.descendant(path: "viewCache")
        lastList = try mirror.descendant(path: "lastList")
    }
}

@available(iOS 13.0, *)
extension DisplayList.Effect: Reflection {
    init(_ mirror: Mirror) throws {
        if let _ = mirror.descendant("identity") {
            self = .identify // never reached
        } else if let (path, style, _) = mirror.descendant("clip") as? (SwiftUI.Path, SwiftUI.FillStyle, Any) {
            self = .clip(path, style)
        } else {
            self = .unknown
        }
    }
}

@available(iOS 13.0, *)
extension DisplayList.ViewUpdater.ViewCache: Reflection {
    init(_ mirror: Mirror) throws {
        map = try mirror.descendant(path: "map")
    }
}

@available(iOS 13.0, *)
extension DisplayList.ViewUpdater.ViewCache.Key: Reflection {
    init(_ mirror: Mirror) throws {
        id = try mirror.descendant(path: "id")
    }
}

@available(iOS 13.0, *)
extension DisplayList.Index.ID: Reflection {
    init(_ mirror: Mirror) throws {
        identity = try mirror.descendant(path: "identity")
    }
}

@available(iOS 13.0, *)
extension DisplayList.ViewUpdater.ViewInfo: Reflection {
    init(_ mirror: Mirror) throws {
        let view = try mirror.descendant(UIView.self, path: "view")
        let layer = try mirror.descendant(CALayer.self, path: "layer")

        // do not retaine the view or layer, only get values required
        // for building wireframe
        backgroundColor = layer.backgroundColor?.safeCast
        borderColor = layer.borderColor?.safeCast
        borderWidth = layer.borderWidth
        cornerRadius = layer.cornerRadius
        alpha = view.alpha
        isHidden = layer.isHidden
        intrinsicContentSize = view.intrinsicContentSize
    }
}

@available(iOS 13.0, *)
extension DisplayList.Content: Reflection {
    init(_ mirror: Mirror) throws {
        seed = try mirror.descendant(path: "seed")
        value = try mirror.descendant(path: "value")
    }
}

@available(iOS 13.0, *)
extension DisplayList.Content.Value: Reflection {
    init(_ mirror: Mirror) throws {
        if let tuple = mirror.descendant("shape") as? (SwiftUI.Path, Any, SwiftUI.FillStyle) {
            let paint = try ResolvedPaint(reflecting: tuple.1)
            self = .shape(tuple.0, paint, tuple.2)
        } else if let tuple = mirror.descendant("text") as? (Any, CGSize) {
            let view = try StyledTextContentView(reflecting: tuple.0)
            self = .text(view, tuple.1)
        } else if let _ = mirror.descendant("platformView") {
            self = .platformView
        } else if let any = mirror.descendant("color") {
            let content = try Color._Resolved(reflecting: any)
            self = .color(content)
        } else {
            self = .unknown
        }
    }
}

@available(iOS 13.0, *)
extension DisplayList.Item: Reflection {
    init(_ mirror: Mirror) throws {
        identity = try mirror.descendant(path: "identity")
        frame = try mirror.descendant(path: "frame")
        value = try mirror.descendant(path: "value")
    }
}

@available(iOS 13.0, *)
extension DisplayList.Item.Value: Reflection {
    init(_ mirror: Mirror) throws {
        if let tuple = mirror.descendant("effect") as? (Any, Any) {
            let effect = try DisplayList.Effect(reflecting: tuple.0)
            let list = try DisplayList(reflecting: tuple.1)
            self = .effect(effect, list)
        } else if let any = mirror.descendant("content") {
            let content = try DisplayList.Content(reflecting: any)
            self = .content(content)
        } else {
            self = .unknown
        }
    }
}
