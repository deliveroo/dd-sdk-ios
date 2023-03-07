/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import UIKit

/// Records `UIPickerView` nodes.
///
/// The look of picker view in SR is approximated by capturing the text from "selected row" and ignoring all other values on the wheel:
/// - If the picker defines multiple components, there will be multiple selected values.
/// - We can't request `picker.dataSource` to receive the value - doing so will result in calling applicaiton code, which could be
/// dangerous (if the code is faulty) and may significantly slow down the performance (e.g. if the underlying source requires database fetch).
/// - Similarly, we don't call `picker.delegate` to avoid running application code outside `UIKit's` lifecycle.
/// - Instead, we infer the value by traversing picker's subtree state and finding texts that are displayed closest to its geometry center.
/// - If privacy mode is elevated, we don't replace individual characters with "x" letter - instead we change whole options to fixed-width mask value.
internal struct UIPickerViewRecorder: NodeRecorder {
    /// Records individual labels in picker's subtree.
    private let labelRecorder: UILabelRecorder
    /// Records all shapes in picker's subtree.
    /// It is used to capture the background of selected option.
    private let selectionRecorder: ViewTreeRecorder
    /// Records all labels in picker's subtree.
    /// It is used to capture titles for displayed options.
    private let labelsRecorder: ViewTreeRecorder

    init() {
        self.labelRecorder = UILabelRecorder()
        self.labelsRecorder = ViewTreeRecorder(nodeRecorders: [labelRecorder])
        self.selectionRecorder = ViewTreeRecorder(nodeRecorders: [UIViewRecorder()])
    }

    func semantics(of view: UIView, with attributes: ViewAttributes, in context: ViewTreeRecordingContext) -> NodeSemantics? {
        guard let picker = view as? UIPickerView else {
            return nil
        }

        guard attributes.isVisible else {
            return InvisibleElement.constant
        }

        // For our "approximation", we render selected option text on top of selection background. However,
        // in the actual `UIPickerView's` tree their order is opposite (blending is used to make the label
        // pass through the shape). For that reason, we record both kinds of nodes separately and then reorder
        // them in returned semantics:
        let backgroundNodes = recordBackgroundOfSelectedOption(in: picker, using: context)
        let titleNodes = recordTitlesOfSelectedOption(in: picker, pickerAttributes: attributes, using: context)

        guard attributes.hasAnyAppearance else {
            // If the root view of `UIPickerView` defines no other appearance (e.g. no custom `.background`), we can
            // safely ignore it, with only forwarding child nodes to final recording.
            return SpecificElement(subtreeStrategy: .ignore, nodes: backgroundNodes + titleNodes)
        }

        // Otherwise, we build dedicated wireframes to describe extra appearance coming from picker's root `UIView`:
        let builder = UIPickerViewWireframesBuilder(
            wireframeRect: attributes.frame,
            attributes: attributes,
            backgroundWireframeID: context.ids.nodeID(for: picker)
        )
        let node = Node(viewAttributes: attributes, wireframesBuilder: builder)
        return SpecificElement(subtreeStrategy: .ignore, nodes: [node] + backgroundNodes + titleNodes)
    }

    /// Records `UIView` nodes that define background of selected option.
    private func recordBackgroundOfSelectedOption(in picker: UIPickerView, using context: ViewTreeRecordingContext) -> [Node] {
        return selectionRecorder.recordNodes(for: picker, in: context)
    }

    /// Records `UILabel` nodes that hold titles of **selected** options - if picker defines N components, there will be N nodes returned.
    private func recordTitlesOfSelectedOption(in picker: UIPickerView, pickerAttributes: ViewAttributes, using context: ViewTreeRecordingContext) -> [Node] {
        labelRecorder.dropPredicate = { _, labelAttributes in
            // We consider option to be "selected" if it is displayed close enough to picker's geometry center
            // and its `UILabel` is opaque:
            let isNearCenter = abs(labelAttributes.frame.midY - pickerAttributes.frame.midY) < 10
            let isForeground = labelAttributes.alpha == 1
            let isSelectedOption = isNearCenter && isForeground
            return !isSelectedOption // drop other options than selected one
        }

        labelRecorder.builderOverride = { builder in
            var builder = builder
            builder.textAlignment = .init(horizontal: .center, vertical: .center)
            return builder
        }

        var context = context
        context.textObfuscator = InputTextObfuscator()
        return labelsRecorder.recordNodes(for: picker, in: context)
    }
}

internal struct UIPickerViewWireframesBuilder: NodeWireframesBuilder {
    var wireframeRect: CGRect
    let attributes: ViewAttributes
    let backgroundWireframeID: WireframeID

    func buildWireframes(with builder: WireframesBuilder) -> [SRWireframe] {
        return [
            builder.createShapeWireframe(
                id: backgroundWireframeID,
                frame: wireframeRect,
                attributes: attributes
            )
        ]
    }
}