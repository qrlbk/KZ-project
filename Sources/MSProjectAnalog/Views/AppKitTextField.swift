import SwiftUI
import AppKit

/// Надёжный текстовый инпут для macOS: обёртка над NSTextField.
struct AppKitTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.placeholderString = placeholder
        field.isEditable = true
        field.isSelectable = true
        field.isEnabled = true
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        field.isBezeled = true
        field.isBordered = true
        field.drawsBackground = true
        field.focusRingType = .default
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.commit(_:))
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Важно: не перезаписывать stringValue во время редактирования/фокуса,
        // иначе ввод может «откатываться» из-за частых updateNSView.
        let isEditing = context.coordinator.isEditing
        let hasFocus = nsView.window?.firstResponder == nsView.currentEditor()
        if !isEditing, !hasFocus, nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var isEditing: Bool = false
        init(text: Binding<String>) { self.text = text }

        func controlTextDidBeginEditing(_ obj: Notification) {
            isEditing = true
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            isEditing = false
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Commit on Enter, but keep default behavior for other keys.
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                text.wrappedValue = (control as? NSTextField)?.stringValue ?? text.wrappedValue
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }

        @objc func commit(_ sender: NSTextField) {
            text.wrappedValue = sender.stringValue
        }
    }
}

