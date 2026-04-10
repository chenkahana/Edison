import Carbon
import SwiftUI

struct ShortcutEditorRow: View {
    let action: ShortcutAction
    @Binding var shortcut: Shortcut

    var body: some View {
        HStack {
            Text(action.title)
            Spacer()
            Stepper("Key code: \(shortcut.keyCode)", value: Binding(
                get: { Int(shortcut.keyCode) },
                set: { shortcut.keyCode = UInt32($0) }
            ), in: 0...127)
                .frame(width: 180)
            Toggle("⌘", isOn: modifierBinding(mask: UInt32(cmdKey)))
                .toggleStyle(.checkbox)
            Toggle("⇧", isOn: modifierBinding(mask: UInt32(shiftKey)))
                .toggleStyle(.checkbox)
            Toggle("⌥", isOn: modifierBinding(mask: UInt32(optionKey)))
                .toggleStyle(.checkbox)
            Toggle("⌃", isOn: modifierBinding(mask: UInt32(controlKey)))
                .toggleStyle(.checkbox)
        }
    }

    private func modifierBinding(mask: UInt32) -> Binding<Bool> {
        Binding(
            get: { shortcut.modifiers & mask != 0 },
            set: { enabled in
                if enabled {
                    shortcut.modifiers |= mask
                } else {
                    shortcut.modifiers &= ~mask
                }
            }
        )
    }
}
