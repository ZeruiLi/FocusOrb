import SwiftUI

struct QuickNotePopoverView: View {
    @ObservedObject var captureStore: CaptureStore
    let onClose: () -> Void

    @State private var noteText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("Quick Note"))
                .font(.system(.headline, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)

            Text(L10n.string("Write and press Enter"))
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textMuted)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.string("Note"))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)

                TextField(L10n.string("Write a short note..."), text: $noteText)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .onSubmit(saveNote)
            }

            HStack {
                Button(L10n.string("Cancel"), action: onClose)
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                Spacer()

                PrimaryCapsuleButton(title: "Save", systemImage: "checkmark", style: .focus, action: saveNote)
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(Material.thin)
        .onAppear {
            inputFocused = true
        }
    }

    private func saveNote() {
        let normalized = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        captureStore.addNote(content: normalized, source: .manual, sessionId: nil)
        noteText = ""
        onClose()
    }
}

