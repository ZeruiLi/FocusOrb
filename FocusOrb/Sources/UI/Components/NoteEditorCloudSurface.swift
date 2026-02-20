import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct NoteEditorCloudSurface: View {
    @Binding var title: String
    @Binding var content: String
    var titleFocus: FocusState<Bool>.Binding
    var titlePlaceholder: String = "Title"
    var bodyPlaceholder: String = "Start writing your note here..."
    var onDelete: (() -> Void)?
    var onPasteImages: (() -> Bool)?

    private let cloudShape = NoteEditorCloudShape()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                TextField(L10n.string(titlePlaceholder), text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 44, weight: .regular, design: .rounded))
                    .foregroundColor(AppTheme.Colors.captureTextPrimary)
                    .padding(.top, 4)
                    .frame(minHeight: 72, alignment: .bottomLeading)
                    .focused(titleFocus)
                    .accessibilityLabel(Text(L10n.string("Note title")))

                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .regular))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.Colors.captureDanger)
                    .accessibilityLabel(Text(L10n.string("Delete note")))
                }
            }

            Rectangle()
                .fill(AppTheme.Colors.captureEditorLine)
                .frame(height: 1)

            Text(L10n.string("Body"))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.captureTextPrimary)

            ZStack(alignment: .topLeading) {
                if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(L10n.string(bodyPlaceholder))
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .foregroundColor(AppTheme.Colors.captureTextMuted)
                        .padding(.top, 8)
                        .padding(.leading, 6)
                }

                PasteInterceptingTextEditor(
                    text: $content,
                    onPasteImages: onPasteImages
                )
                .accessibilityLabel(Text(L10n.string("Note body")))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 26)
        .padding(.top, 52)
        .padding(.bottom, 28)
        .background {
            ZStack {
                cloudShape.fill(AppTheme.Effects.cardMaterial)
                cloudShape.fill(AppTheme.Colors.captureEditorSurface)
            }
        }
        .clipShape(cloudShape)
        .overlay(
            cloudShape
                .stroke(AppTheme.Colors.captureSurfaceStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct PasteInterceptingTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onPasteImages: (() -> Bool)?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textContainer = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let textView = PasteInterceptingNSTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.string = text
        textView.onPasteImages = onPasteImages
        textView.drawsBackground = false
        textView.backgroundColor = NSColor.clear
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.minSize = NSSize.zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = NSView.AutoresizingMask.width
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textColor = NSColor.labelColor
        textView.font = roundedBodyFont()

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? PasteInterceptingNSTextView else { return }
        textView.onPasteImages = onPasteImages
        textView.font = roundedBodyFont()
        textView.textColor = NSColor.labelColor
        if textView.string != text {
            textView.string = text
        }
    }

    private func roundedBodyFont() -> NSFont {
        let base = NSFont.systemFont(ofSize: 22, weight: .regular)
        if let descriptor = base.fontDescriptor.withDesign(.rounded) {
            return NSFont(descriptor: descriptor, size: 22) ?? base
        }
        return base
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

private final class PasteInterceptingNSTextView: NSTextView {
    var onPasteImages: (() -> Bool)?

    override func paste(_ sender: Any?) {
        if onPasteImages?() == true {
            return
        }
        super.paste(sender)
    }
}

private struct NoteEditorCloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        let width = rect.width
        let midX = rect.midX

        let cornerRadius = min(38, width * 0.06)
        let cloudBaseY = minY + min(max(rect.height * 0.16, 58), 72)

        let x1 = minX + width * 0.09
        let x2 = minX + width * 0.24
        let x3 = minX + width * 0.41
        let x4 = minX + width * 0.59
        let x5 = minX + width * 0.76
        let x6 = minX + width * 0.91

        var path = Path()
        path.move(to: CGPoint(x: minX + cornerRadius, y: cloudBaseY))
        path.addLine(to: CGPoint(x: x1, y: cloudBaseY))

        path.addQuadCurve(
            to: CGPoint(x: x2, y: cloudBaseY),
            control: CGPoint(x: (x1 + x2) * 0.5, y: cloudBaseY - 16)
        )
        path.addQuadCurve(
            to: CGPoint(x: x3, y: cloudBaseY),
            control: CGPoint(x: (x2 + x3) * 0.5, y: cloudBaseY - 28)
        )
        path.addQuadCurve(
            to: CGPoint(x: x4, y: cloudBaseY),
            control: CGPoint(x: midX, y: cloudBaseY - 36)
        )
        path.addQuadCurve(
            to: CGPoint(x: x5, y: cloudBaseY),
            control: CGPoint(x: (x4 + x5) * 0.5, y: cloudBaseY - 28)
        )
        path.addQuadCurve(
            to: CGPoint(x: x6, y: cloudBaseY),
            control: CGPoint(x: (x5 + x6) * 0.5, y: cloudBaseY - 16)
        )

        path.addLine(to: CGPoint(x: maxX - cornerRadius, y: cloudBaseY))
        path.addQuadCurve(
            to: CGPoint(x: maxX, y: cloudBaseY + cornerRadius),
            control: CGPoint(x: maxX, y: cloudBaseY)
        )
        path.addLine(to: CGPoint(x: maxX, y: maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: maxX - cornerRadius, y: maxY),
            control: CGPoint(x: maxX, y: maxY)
        )
        path.addLine(to: CGPoint(x: minX + cornerRadius, y: maxY))
        path.addQuadCurve(
            to: CGPoint(x: minX, y: maxY - cornerRadius),
            control: CGPoint(x: minX, y: maxY)
        )
        path.addLine(to: CGPoint(x: minX, y: cloudBaseY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: minX + cornerRadius, y: cloudBaseY),
            control: CGPoint(x: minX, y: cloudBaseY)
        )

        return path
    }
}
