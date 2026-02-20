import SwiftUI
import AppKit
import UniformTypeIdentifiers

private enum ClipViewMode: String, CaseIterable, Identifiable {
    case text
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: return L10n.string("Text")
        case .image: return L10n.string("Image")
        }
    }
}

struct CaptureDrawerView: View {
    @ObservedObject var captureStore: CaptureStore = .shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedTab: CaptureTab
    @State private var createText = ""
    @State private var searchText = ""
    @State private var editingNote: NoteItem?
    @State private var isCreatingNote = false
    @State private var editingTask: TaskItem?
    @State private var exportError: String?
    @State private var clipViewMode: ClipViewMode = .text
    @FocusState private var createInputFocused: Bool

    init(initialTab: CaptureTab = .notes) {
        _selectedTab = State(initialValue: initialTab)
    }

    private var filteredNotes: [NoteItem] {
        captureStore.searchNotes(searchText)
    }

    private var filteredTasks: (active: [TaskItem], completed: [TaskItem]) {
        captureStore.filteredTasks(searchText)
    }

    private var filteredTextClips: [ClipItem] {
        captureStore.searchTextClips(searchText)
    }

    private var filteredImageClips: [ClipItem] {
        let normalized = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let clips = captureStore.imageClips()
        guard !normalized.isEmpty else { return clips }
        return clips.filter { clip in
            guard let path = clip.imagePath else { return false }
            let fileName = URL(fileURLWithPath: path).lastPathComponent
            return fileName.localizedCaseInsensitiveContains(normalized)
        }
    }

    private var visibleClips: [ClipItem] {
        switch clipViewMode {
        case .text:
            return filteredTextClips
        case .image:
            return filteredImageClips
        }
    }

    private var clipSearchPlaceholder: String {
        switch clipViewMode {
        case .text:
            return L10n.string("Search Text Clips...")
        case .image:
            return L10n.string("Search Image Clips...")
        }
    }

    private var clipClearTitle: String {
        switch clipViewMode {
        case .text:
            return L10n.string("Clear Text")
        case .image:
            return L10n.string("Clear Images")
        }
    }

    private var topPanelMode: CaptureCloudTopMode {
        switch selectedTab {
        case .notes:
            return .notes
        case .tasks:
            return .tasks
        case .clips:
            return .clips
        }
    }

    var body: some View {
        ZStack {
            captureBackground.ignoresSafeArea()

            GeometryReader { proxy in
                let columnWidth = min(max(proxy.size.width - 56, 560), 640)

                VStack(spacing: 20) {
                    CaptureCloudTopPanel(
                        mode: topPanelMode,
                        selectedTab: $selectedTab,
                        searchText: $searchText
                    )
                    contextActionBar
                    contentBody
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(width: columnWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 22)
                .padding(.bottom, 18)
            }
        }
        .frame(minWidth: 660, minHeight: 820)
        .onAppear {
            captureStore.reload()
            createInputFocused = selectedTab == .tasks
        }
        .onChange(of: selectedTab) { _, newValue in
            createText = ""
            searchText = ""
            createInputFocused = newValue == .tasks
        }
        .sheet(isPresented: $isCreatingNote) {
            NotebookEditorSheet(
                note: nil,
                importImages: { captureStore.importNoteImages(from: $0) },
                importPastedImages: { captureStore.importNoteImages(from: $0) },
                onSave: { draft in
                    captureStore.addNote(
                        title: draft.title,
                        content: draft.content,
                        template: draft.template,
                        source: .manual,
                        sessionId: nil,
                        imagePaths: draft.imagePaths
                    )
                },
                onDelete: nil
            )
        }
        .sheet(item: $editingNote) { note in
            NotebookEditorSheet(
                note: note,
                importImages: { captureStore.importNoteImages(from: $0) },
                importPastedImages: { captureStore.importNoteImages(from: $0) },
                onSave: { draft in
                    captureStore.updateNote(
                        noteID: note.id,
                        title: draft.title,
                        content: draft.content,
                        template: draft.template,
                        imagePaths: draft.imagePaths
                    )
                },
                onDelete: {
                    captureStore.deleteNote(noteID: note.id)
                }
            )
        }
        .sheet(item: $editingTask) { task in
            TaskEditorSheet(task: task) { title in
                captureStore.updateTask(taskID: task.id, title: title)
            }
        }
        .alert(
            L10n.string("Export Failed"),
            isPresented: Binding(
                get: { exportError != nil },
                set: { _ in exportError = nil }
            )
        ) {
            Button(L10n.string("OK"), role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .animation(
            reduceMotion ? .none : .easeInOut(duration: 0.22),
            value: selectedTab
        )
    }

    private var captureBackground: some View {
        LinearGradient(
            colors: [AppTheme.Colors.captureBackgroundTop, AppTheme.Colors.captureBackgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(AppTheme.Colors.captureMintGlow.opacity(0.18))
                .frame(width: 180, height: 180)
                .blur(radius: 38)
                .offset(x: -106, y: -98)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(AppTheme.Colors.captureMintGlow.opacity(0.14))
                .frame(width: 220, height: 220)
                .blur(radius: 46)
                .offset(x: 120, y: 116)
        }
    }

    @ViewBuilder
    private var contextActionBar: some View {
        switch selectedTab {
        case .notes:
            captureActionPanel {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.string("Notebook"))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppTheme.Colors.captureTextSecondary)
                        Text(L10n.string("Create first, then edit title, content, template, and images."))
                            .font(.caption2)
                            .foregroundColor(AppTheme.Colors.captureTextMuted)
                    }

                    Spacer()

                    PrimaryCapsuleButton(title: "Create", systemImage: "square.and.pencil", style: .focus) {
                        isCreatingNote = true
                    }
                }
            }
        case .tasks:
            CaptureTaskComposerCard(
                createText: $createText,
                searchText: $searchText,
                onSubmit: commitCreateInput,
                onReset: { captureStore.resetTaskOrderToDefault() },
                createInputFocus: $createInputFocused
            )
        case .clips:
            captureActionPanel {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Text(L10n.string("Click a row to copy back to clipboard."))
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.captureTextMuted)
                        Spacer()
                        Button(clipClearTitle) {
                            clearCurrentClipType()
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppTheme.Colors.captureTextSecondary)
                        .disabled(visibleClips.isEmpty)
                        .accessibilityLabel(Text(clipClearTitle))
                    }

                    Picker(L10n.string("Clip Type"), selection: $clipViewMode) {
                        ForEach(ClipViewMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private func captureActionPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.Colors.captureSurfaceStrong.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.Colors.captureSurfaceStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private func captureContentPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.Colors.captureSurfaceStrong.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.Colors.captureSurfaceStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private var contentBody: some View {
        switch selectedTab {
        case .notes:
            notesBody
        case .tasks:
            tasksBody
        case .clips:
            clipsBody
        }
    }

    private var notesBody: some View {
        Group {
            if filteredNotes.isEmpty {
                VStack(spacing: 0) {
                    Spacer(minLength: 26)
                    emptyState(
                        icon: "note.text",
                        title: "No notes yet",
                        subtitle: ""
                    )
                    Spacer(minLength: 64)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                captureContentPanel {
                    VStack(spacing: 10) {
                        HStack {
                            Text(L10n.string("XHS-style note cards"))
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.captureTextMuted)
                            Spacer()
                            Text(L10n.string("%d notes", filteredNotes.count))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppTheme.Colors.captureTextSecondary)
                        }

                        ScrollView {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 230), spacing: 12)],
                                spacing: 12
                            ) {
                                ForEach(filteredNotes) { note in
                                    noteCard(note)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    private var tasksBody: some View {
        Group {
            if filteredTasks.active.isEmpty && filteredTasks.completed.isEmpty {
                emptyState(
                    icon: "checklist",
                    title: "No tasks yet",
                    subtitle: "Write your next task from the input above."
                )
            } else {
                captureContentPanel {
                    List {
                        if !filteredTasks.active.isEmpty {
                            Section {
                                ForEach(filteredTasks.active) { task in
                                    taskRow(task)
                                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                        .listRowBackground(Color.clear)
                                }
                                .onMove(perform: moveActiveTasks)
                            } header: {
                                taskSectionHeader("Active")
                            }
                        }

                        if !filteredTasks.completed.isEmpty {
                            Section {
                                ForEach(filteredTasks.completed) { task in
                                    taskRow(task)
                                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                        .listRowBackground(Color.clear)
                                }
                            } header: {
                                taskSectionHeader("Completed")
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 360)
                }
            }
        }
    }

    private var clipsBody: some View {
        CaptureCloudListCard(
            searchText: $searchText,
            placeholder: clipSearchPlaceholder
        ) {
            if visibleClips.isEmpty {
                emptyState(
                    icon: "doc.on.clipboard",
                    title: clipViewMode == .text ? "No text clips yet" : "No image clips yet",
                    subtitle: clipViewMode == .text
                        ? "Clipboard text history will appear here."
                        : "Clipboard image history will appear here."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(visibleClips.enumerated()), id: \.element.id) { index, clip in
                            if clipViewMode == .image {
                                imageClipRow(clip)
                            } else {
                                clipRow(clip)
                            }
                            if index < visibleClips.count - 1 {
                                Rectangle()
                                    .fill(AppTheme.Colors.captureRowSeparator)
                                    .frame(height: 1)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private func taskSectionHeader(_ title: String) -> some View {
        HStack {
            Text(L10n.string(title))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.captureTextSecondary)
            Spacer()
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
        .textCase(nil)
    }

    private func noteCard(_ note: NoteItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                noteVisual(for: note)

                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black.opacity(0.45)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(note.resolvedTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(note.previewText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
            }
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if !note.imagePaths.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.fill")
                        Text("\(note.imagePaths.count)")
                    }
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(8)
                }
            }

            HStack(spacing: 8) {
                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(AppTheme.Colors.captureTextMuted)

                Spacer()

                noteActionButton(label: "编辑笔记", systemImage: "square.and.pencil", tint: AppTheme.Colors.captureTextSecondary) {
                    editingNote = note
                }

                noteActionButton(label: "导出笔记", systemImage: "square.and.arrow.up", tint: AppTheme.Colors.captureMintDeep) {
                    exportNoteAsXHS(note)
                }

                noteActionButton(label: "删除笔记", systemImage: "trash", tint: AppTheme.Colors.captureDanger.opacity(0.85)) {
                    captureStore.deleteNote(noteID: note.id)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.captureSurfaceStrong)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.Colors.captureSurfaceStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private func noteVisual(for note: NoteItem) -> some View {
        if let image = note.primaryImagePath.flatMap(loadImageFromDisk) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(
                colors: note.template.palette.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(alignment: .topTrailing) {
                Text(note.template.title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(note.template.palette.badgeText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(note.template.palette.badgeBackground, in: Capsule())
                    .padding(10)
            }
        }
    }

    private func noteActionButton(label: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(tint)
        .accessibilityLabel(Text(L10n.string(label)))
    }

    @ViewBuilder
    private func taskRow(_ task: TaskItem) -> some View {
        HStack(spacing: 8) {
            Button {
                captureStore.toggleTaskDone(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(task.isCompleted ? AppTheme.Colors.captureMintDeep : AppTheme.Colors.captureIconMuted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(task.isCompleted ? L10n.string("Mark task incomplete") : L10n.string("Mark task complete")))

            Text(task.title)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundColor(task.isCompleted ? AppTheme.Colors.captureTextMuted : AppTheme.Colors.captureTextPrimary)
                .strikethrough(task.isCompleted, color: AppTheme.Colors.captureTextMuted)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                editingTask = task
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 21, weight: .regular))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundColor(AppTheme.Colors.captureIconMuted)
            .accessibilityLabel(Text(L10n.string("编辑任务")))

            Button {
                captureStore.deleteTask(taskID: task.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 21, weight: .regular))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundColor(AppTheme.Colors.captureIconMuted)
            .accessibilityLabel(Text(L10n.string("删除任务")))
        }
        .padding(.vertical, 6)
        .frame(minHeight: 72)
    }

    @ViewBuilder
    private func imageClipRow(_ clip: ClipItem) -> some View {
        HStack(spacing: 8) {
            Button {
                captureStore.copyClipToPasteboard(clip)
            } label: {
                HStack(spacing: 10) {
                    Group {
                        if let path = clip.imagePath, let image = NSImage(contentsOfFile: path) {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.2))
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(AppTheme.Colors.captureTextMuted)
                                )
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("Image Clip"))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.captureTextPrimary)

                        if let imagePath = clip.imagePath {
                            Text(URL(fileURLWithPath: imagePath).lastPathComponent)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(AppTheme.Colors.captureTextMuted)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Text(clip.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.Colors.captureTextMuted.opacity(0.9))
                    }

                    Spacer(minLength: 8)
                }
            }
            .buttonStyle(.plain)

            Button {
                captureStore.setClipPinned(clipID: clip.id, isPinned: !clip.isPinned)
            } label: {
                Image(systemName: clip.isPinned ? "pin.slash" : "pin")
                    .font(.system(size: 21, weight: .regular))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundColor(clip.isPinned ? AppTheme.Colors.captureActionTeal : AppTheme.Colors.captureIconMuted)
            .accessibilityLabel(Text(clip.isPinned ? L10n.string("取消置顶") : L10n.string("置顶")))

            Button {
                captureStore.deleteClip(clipID: clip.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 21, weight: .regular))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundColor(AppTheme.Colors.captureIconMuted)
            .accessibilityLabel(Text(L10n.string("删除剪贴")))
        }
        .padding(.vertical, 10)
        .frame(minHeight: 84)
    }

    @ViewBuilder
    private func clipRow(_ clip: ClipItem) -> some View {
        HStack(spacing: 8) {
            Button {
                captureStore.copyClipToPasteboard(clip)
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(clip.content)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.Colors.captureTextPrimary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .multilineTextAlignment(.leading)

                        Text(clip.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.Colors.captureTextMuted.opacity(0.9))
                    }

                    Spacer(minLength: 8)
                }
            }
            .buttonStyle(.plain)

            Button {
                captureStore.setClipPinned(clipID: clip.id, isPinned: !clip.isPinned)
            } label: {
                Image(systemName: clip.isPinned ? "pin.slash" : "pin")
                    .font(.system(size: 21, weight: .regular))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundColor(clip.isPinned ? AppTheme.Colors.captureActionTeal : AppTheme.Colors.captureIconMuted)
            .accessibilityLabel(Text(clip.isPinned ? L10n.string("取消置顶") : L10n.string("置顶")))

            Button {
                captureStore.deleteClip(clipID: clip.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 21, weight: .regular))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundColor(AppTheme.Colors.captureIconMuted)
            .accessibilityLabel(Text(L10n.string("删除剪贴")))
        }
        .padding(.vertical, 10)
        .frame(minHeight: 72)
    }

    @ViewBuilder
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        CaptureEmptyCloudState(icon: icon, title: title, subtitle: subtitle)
    }

    private func clearCurrentClipType() {
        switch clipViewMode {
        case .text:
            captureStore.clearTextClips()
        case .image:
            captureStore.clearImageClips()
        }
    }

    private func commitCreateInput() {
        let value = createText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        guard selectedTab == .tasks else { return }

        captureStore.addTask(title: value)
        createText = ""
    }

    private func moveActiveTasks(from source: IndexSet, to destination: Int) {
        var reordered = filteredTasks.active
        reordered.move(fromOffsets: source, toOffset: destination)
        captureStore.reorderActiveTasks(idsInOrder: reordered.map(\.id))
    }

    private func exportNoteAsXHS(_ note: NoteItem) {
        let renderer = ImageRenderer(content: XHSNoteExportView(note: note))
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: 540, height: 675)

        guard let nsImage = renderer.nsImage else {
            exportError = L10n.string("Unable to generate note card image.")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.png]
        panel.nameFieldStringValue = L10n.string("FocusOrb-Note-%@.png", exportDateString())

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard
            let tiffData = nsImage.tiffRepresentation,
            let imageRep = NSBitmapImageRep(data: tiffData),
            let pngData = imageRep.representation(using: .png, properties: [:])
        else {
            exportError = L10n.string("Export failed while encoding PNG.")
            return
        }

        do {
            try pngData.write(to: url, options: [.atomic])
        } catch {
            exportError = L10n.string("Failed to save image: %@", error.localizedDescription)
        }
    }

    private func loadImageFromDisk(path: String) -> NSImage? {
        NSImage(contentsOfFile: path)
    }

    private func exportDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: Date())
    }
}

private struct NoteEditorDraft {
    let title: String
    let content: String
    let template: NoteTemplate
    let imagePaths: [String]
}

private struct NotebookEditorSheet: View {
    let note: NoteItem?
    let importImages: ([URL]) -> [String]
    let importPastedImages: ([NSImage]) -> [String]
    let onSave: (NoteEditorDraft) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var content: String
    @State private var template: NoteTemplate
    @State private var imagePaths: [String]
    @State private var showingImporter = false
    @State private var importError: String?
    @State private var attachmentsExpanded = false
    @FocusState private var titleFocused: Bool

    init(
        note: NoteItem?,
        importImages: @escaping ([URL]) -> [String],
        importPastedImages: @escaping ([NSImage]) -> [String],
        onSave: @escaping (NoteEditorDraft) -> Void,
        onDelete: (() -> Void)?
    ) {
        self.note = note
        self.importImages = importImages
        self.importPastedImages = importPastedImages
        self.onSave = onSave
        self.onDelete = onDelete

        _title = State(initialValue: note?.resolvedTitle ?? "")
        _content = State(initialValue: note?.content ?? "")
        _template = State(initialValue: note?.template ?? .clean)
        _imagePaths = State(initialValue: note?.imagePaths ?? [])
    }

    private var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty || !trimmedContent.isEmpty || !imagePaths.isEmpty
    }

    var body: some View {
        GeometryReader { proxy in
            let chromeWidth = min(max(proxy.size.width - 24, 540), 680)
            let editorHeight = min(max(proxy.size.height * 0.62, 420), 620)

            VStack(spacing: 14) {
                HStack {
                    Button(L10n.string("Cancel")) {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 22, weight: .regular, design: .rounded))
                    .foregroundColor(AppTheme.Colors.captureTextPrimary)

                    Spacer()

                    Button(L10n.string("Save")) {
                        save()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(canSave ? AppTheme.Colors.captureTextPrimary : AppTheme.Colors.captureTextMuted)
                    .disabled(!canSave)
                }
                .padding(.horizontal, 6)

                ScrollView {
                    VStack(spacing: 14) {
                        NoteEditorCloudSurface(
                            title: $title,
                            content: $content,
                            titleFocus: $titleFocused,
                            titlePlaceholder: "Title",
                            bodyPlaceholder: "Start writing your note here...",
                            onDelete: onDelete.map { deleteAction in
                                {
                                    deleteAction()
                                    dismiss()
                                }
                            },
                            onPasteImages: pasteImagesFromPasteboard
                        )
                        .frame(height: editorHeight)

                        VStack(spacing: 10) {
                            HStack(spacing: 18) {
                                ForEach(NoteTemplate.allCases) { option in
                                    templateDot(for: option)
                                }
                            }
                            .padding(.top, 2)

                            attachmentsBar
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(maxWidth: chromeWidth)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(minWidth: 560, idealWidth: 680, maxWidth: 760, minHeight: 700, idealHeight: 820, maxHeight: 940)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                appendImportedImagePaths(importImages(urls))
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert(
            L10n.string("Image Import Failed"),
            isPresented: Binding(
                get: { importError != nil },
                set: { _ in importError = nil }
            )
        ) {
            Button(L10n.string("OK"), role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .onAppear {
            titleFocused = true
            attachmentsExpanded = !imagePaths.isEmpty
        }
    }

    private func templateDot(for option: NoteTemplate) -> some View {
        Button {
            template = option
        } label: {
            Circle()
                .fill(
                    LinearGradient(
                        colors: option.palette.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(template == option ? AppTheme.Colors.captureTextPrimary.opacity(0.55) : Color.clear, lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(template == option ? 0.16 : 0.08), radius: template == option ? 10 : 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.string("Use %@ template", option.title)))
    }

    private var attachmentsBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        attachmentsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: attachmentsExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                        Text(L10n.string("Attachments"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Text("(\(imagePaths.count))")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                    }
                    .foregroundColor(AppTheme.Colors.captureTextSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    showingImporter = true
                } label: {
                    Label(L10n.string("Add Images"), systemImage: "photo.badge.plus")
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.captureActionTeal)
            }

            if attachmentsExpanded {
                if imagePaths.isEmpty {
                    Text(L10n.string("No images attached."))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(AppTheme.Colors.captureTextMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(imagePaths, id: \.self) { path in
                                noteImageThumbnail(path: path)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func noteImageThumbnail(path: String) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = NSImage(contentsOfFile: path) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 96, height: 96)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(AppTheme.Colors.textMuted)
                        )
                }
            }

            Button {
                imagePaths.removeAll { $0 == path }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.5))
                    )
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
    }

    private func appendImportedImagePaths(_ imported: [String]) {
        guard !imported.isEmpty else { return }
        var seen = Set<String>()
        imagePaths = (imagePaths + imported).filter { path in
            seen.insert(path).inserted
        }
        attachmentsExpanded = true
    }

    private func pasteImagesFromPasteboard() -> Bool {
        let pasteboard = NSPasteboard.general
        let urls = imageFileURLs(from: pasteboard)
        if !urls.isEmpty {
            let importedFromURLs = importImages(urls)
            if !importedFromURLs.isEmpty {
                appendImportedImagePaths(importedFromURLs)
                return true
            }
        }

        if
            let images = (pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage]),
            !images.isEmpty
        {
            let importedFromImages = importPastedImages(images)
            if !importedFromImages.isEmpty {
                appendImportedImagePaths(importedFromImages)
                return true
            }
        }

        let dataImages = imagePayloadsFromPasteboardData(pasteboard)
        if !dataImages.isEmpty {
            let importedFromData = importPastedImages(dataImages)
            if !importedFromData.isEmpty {
                appendImportedImagePaths(importedFromData)
                return true
            }
        }

        if let pathURL = imageFileURLFromPasteboardString(pasteboard) {
            let importedFromPath = importImages([pathURL])
            if !importedFromPath.isEmpty {
                appendImportedImagePaths(importedFromPath)
                return true
            }
        }

        return false
    }

    private func imageFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
            return []
        }
        return urls.filter(isImageFileURL(_:))
    }

    private func isImageFileURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else {
            return false
        }
        return type.conforms(to: .image)
    }

    private func imagePayloadsFromPasteboardData(_ pasteboard: NSPasteboard) -> [NSImage] {
        let typeIdentifiers = [
            UTType.png.identifier,
            UTType.tiff.identifier,
            UTType.jpeg.identifier,
            UTType.heic.identifier,
            UTType.image.identifier
        ]

        for identifier in typeIdentifiers {
            let type = NSPasteboard.PasteboardType(identifier)
            if
                let data = pasteboard.data(forType: type),
                !data.isEmpty,
                let image = NSImage(data: data)
            {
                return [image]
            }
        }

        return []
    }

    private func imageFileURLFromPasteboardString(_ pasteboard: NSPasteboard) -> URL? {
        guard let raw = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else {
            return nil
        }

        let candidateURL: URL?
        if raw.hasPrefix("file://") {
            candidateURL = URL(string: raw)
        } else if raw.hasPrefix("/") {
            candidateURL = URL(fileURLWithPath: raw)
        } else {
            candidateURL = nil
        }

        guard let candidateURL, candidateURL.isFileURL else {
            return nil
        }
        guard FileManager.default.fileExists(atPath: candidateURL.path), isImageFileURL(candidateURL) else {
            return nil
        }
        return candidateURL
    }

    private func save() {
        guard canSave else { return }
        onSave(
            NoteEditorDraft(
                title: title,
                content: content,
                template: template,
                imagePaths: imagePaths
            )
        )
        dismiss()
    }
}

private struct XHSNoteExportView: View {
    let note: NoteItem

    var body: some View {
        ZStack {
            OrbExportBackground(cornerRadius: 30)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: note.template.palette.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("FocusOrb Notes"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.exportTextSecondary)
                        Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.Colors.exportTextSecondary.opacity(0.86))
                    }

                    Spacer()

                    Text(L10n.string("XHS"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(note.template.palette.badgeText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(note.template.palette.badgeBackground, in: Capsule())
                }

                Group {
                    if let image = note.primaryImagePath.flatMap({ NSImage(contentsOfFile: $0) }) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 268)
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: note.template.palette.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 268)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(note.template.palette.badgeText.opacity(0.94))
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.38), lineWidth: 1)
                )

                OrbExportSurface(padding: 14, cornerRadius: 16, emphasized: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.resolvedTitle)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.exportTextPrimary)

                        Text(note.content.isEmpty ? " " : note.content)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.Colors.exportTextSecondary)
                            .lineSpacing(4)
                            .lineLimit(9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                HStack {
                    Text("#\(note.template.title)")
                    if note.source == .reflection {
                        Text(L10n.string("#Reflection"))
                    }
                    Spacer()
                    Text(L10n.string("via FocusOrb"))
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.exportTextSecondary.opacity(0.92))
            }
            .padding(24)
        }
        .frame(width: 540, height: 675)
    }
}

private struct TaskEditorSheet: View {
    let task: TaskItem
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @FocusState private var focused: Bool

    init(task: TaskItem, onSave: @escaping (String) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task.title)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button(L10n.string("Cancel")) { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .foregroundColor(AppTheme.Colors.captureTextPrimary)

                Spacer()

                Button(L10n.string("Save")) { save() }
                    .buttonStyle(.plain)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.captureTextPrimary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.string("Task"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.captureTextSecondary)

                TextField(L10n.string("Task title"), text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.Colors.captureEditorSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.Colors.captureInsetStroke, lineWidth: 1)
                    )
                    .focused($focused)
                    .onSubmit(save)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppTheme.Colors.captureSurfaceStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.Colors.captureSurfaceStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 8)
        }
        .padding(18)
        .frame(width: 520)
        .onAppear {
            focused = true
        }
    }

    private func save() {
        onSave(title)
        dismiss()
    }
}

private struct NoteTemplatePalette {
    let gradient: [Color]
    let badgeBackground: Color
    let badgeText: Color
}

private extension NoteTemplate {
    var palette: NoteTemplatePalette {
        switch self {
        case .clean:
            return NoteTemplatePalette(
                gradient: [Color(red: 0.35, green: 0.68, blue: 0.96), Color(red: 0.57, green: 0.84, blue: 1.0)],
                badgeBackground: Color.white.opacity(0.80),
                badgeText: Color(red: 0.18, green: 0.34, blue: 0.56)
            )
        case .warm:
            return NoteTemplatePalette(
                gradient: [Color(red: 0.98, green: 0.66, blue: 0.44), Color(red: 0.95, green: 0.49, blue: 0.33)],
                badgeBackground: Color.white.opacity(0.78),
                badgeText: Color(red: 0.46, green: 0.23, blue: 0.12)
            )
        case .mint:
            return NoteTemplatePalette(
                gradient: [Color(red: 0.19, green: 0.80, blue: 0.68), Color(red: 0.52, green: 0.94, blue: 0.83)],
                badgeBackground: Color.white.opacity(0.80),
                badgeText: Color(red: 0.10, green: 0.37, blue: 0.31)
            )
        case .dusk:
            return NoteTemplatePalette(
                gradient: [Color(red: 0.36, green: 0.35, blue: 0.70), Color(red: 0.16, green: 0.22, blue: 0.43)],
                badgeBackground: Color.white.opacity(0.18),
                badgeText: Color.white.opacity(0.95)
            )
        }
    }
}
