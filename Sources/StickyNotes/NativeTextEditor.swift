import AppKit
import SwiftUI

struct NativeTextEditor: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let focusRequest: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .systemFont(ofSize: fontSize)
        textView.textColor = .labelColor
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(
                NSRange(
                    location: min(selection.location, text.utf16.count),
                    length: 0
                )
            )
        }

        let desiredFont = NSFont.systemFont(ofSize: fontSize)
        if textView.font != desiredFont {
            textView.font = desiredFont
        }

        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async {
                guard scrollView.window?.isVisible == true else { return }
                scrollView.window?.makeFirstResponder(textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: NSTextView?
        var lastFocusRequest: UUID?

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text = textView.string
        }
    }
}
