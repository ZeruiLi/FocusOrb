import Foundation
import GRDB
import AppKit
import UniformTypeIdentifiers

final class CaptureStore: ObservableObject {
    static let shared = CaptureStore()

    @Published private(set) var notes: [NoteItem] = []
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var clips: [ClipItem] = []
    @Published private(set) var topTask: TaskItem?

    private let maxClipCount = 500
    private let database = DatabaseManager.shared

    private init() {
        reload()
    }

    func reload() {
        do {
            let payload = try database.read { db in
                let notes = try NoteItem
                    .order(NoteItem.Columns.createdAt.desc)
                    .fetchAll(db)
                let tasks = try TaskItem
                    .order(TaskItem.Columns.createdAt.asc)
                    .fetchAll(db)
                let clips = try ClipItem
                    .order(ClipItem.Columns.createdAt.desc)
                    .fetchAll(db)
                return (notes: notes, tasks: tasks, clips: clips)
            }
            notes = payload.notes
            tasks = payload.tasks
            clips = payload.clips
            refreshDerivedState()
        } catch {
            print("Failed to reload capture data: \(error)")
            notes = []
            tasks = []
            clips = []
            topTask = nil
        }
    }

    // MARK: - Notes

    func addNote(content: String, source: NoteSource = .manual, sessionId: UUID? = nil) {
        addNote(
            title: nil,
            content: content,
            template: .clean,
            source: source,
            sessionId: sessionId,
            imagePaths: []
        )
    }

    func addNote(
        title: String?,
        content: String,
        template: NoteTemplate = .clean,
        source: NoteSource = .manual,
        sessionId: UUID? = nil,
        imagePaths: [String] = []
    ) {
        let normalizedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRawTitle = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTitle = resolvedNoteTitle(title, content: normalizedContent)
        let normalizedImagePaths = sanitizeImagePaths(imagePaths)

        guard !normalizedContent.isEmpty || !normalizedImagePaths.isEmpty || !normalizedRawTitle.isEmpty else { return }

        let now = Date()
        let item = NoteItem(
            title: normalizedTitle,
            content: normalizedContent,
            createdAt: now,
            updatedAt: now,
            source: source,
            sessionId: sessionId,
            template: template,
            imagePaths: normalizedImagePaths
        )

        do {
            try database.write { db in
                try item.insert(db)
            }
            reload()
        } catch {
            print("Failed to add note: \(error)")
        }
    }

    func updateNote(noteID: UUID, content: String) {
        guard let existing = notes.first(where: { $0.id == noteID }) else { return }
        updateNote(
            noteID: noteID,
            title: existing.title,
            content: content,
            template: existing.template,
            imagePaths: existing.imagePaths
        )
    }

    func updateNote(
        noteID: UUID,
        title: String,
        content: String,
        template: NoteTemplate,
        imagePaths: [String]
    ) {
        let normalizedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRawTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTitle = resolvedNoteTitle(title, content: normalizedContent)
        let normalizedImagePaths = sanitizeImagePaths(imagePaths)

        guard !normalizedContent.isEmpty || !normalizedImagePaths.isEmpty || !normalizedRawTitle.isEmpty else { return }
        let now = Date()

        do {
            let removedImagePaths = try database.write { db -> [String] in
                let existing = try NoteItem
                    .filter(NoteItem.Columns.id == noteID.uuidString)
                    .fetchOne(db)
                let previousPaths = existing?.imagePaths ?? []

                try db.execute(
                    sql: """
                    UPDATE noteItem
                    SET title = ?, content = ?, template = ?, imagePaths = ?, updatedAt = ?
                    WHERE id = ?
                    """,
                    arguments: [
                        normalizedTitle,
                        normalizedContent,
                        template.rawValue,
                        encodeImagePaths(normalizedImagePaths),
                        now,
                        noteID.uuidString
                    ]
                )

                let nextSet = Set(normalizedImagePaths)
                return previousPaths.filter { !nextSet.contains($0) }
            }

            deleteStoredImagesIfNeeded(removedImagePaths)
            reload()
        } catch {
            print("Failed to update note: \(error)")
        }
    }

    func deleteNote(noteID: UUID) {
        do {
            let removedImagePaths = try database.write { db -> [String] in
                let existing = try NoteItem
                    .filter(NoteItem.Columns.id == noteID.uuidString)
                    .fetchOne(db)
                try db.execute(
                    sql: "DELETE FROM noteItem WHERE id = ?",
                    arguments: [noteID.uuidString]
                )
                return existing?.imagePaths ?? []
            }
            deleteStoredImagesIfNeeded(removedImagePaths)
            reload()
        } catch {
            print("Failed to delete note: \(error)")
        }
    }

    func searchNotes(_ query: String) -> [NoteItem] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return notes }
        return notes.filter {
            $0.resolvedTitle.localizedCaseInsensitiveContains(normalized)
            || $0.content.localizedCaseInsensitiveContains(normalized)
        }
    }

    func recentNotes(limit: Int) -> [NoteItem] {
        Array(notes.prefix(limit))
    }

    func importNoteImages(from urls: [URL]) -> [String] {
        guard !urls.isEmpty else { return [] }
        var payloads: [(data: Data, fileExtension: String)] = []

        for url in urls {
            do {
                let didAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                let data = try Data(contentsOf: url)
                let ext = sanitizedFileExtension(url.pathExtension)
                payloads.append((data: data, fileExtension: ext))
            } catch {
                print("Failed to import note image \(url.lastPathComponent): \(error)")
            }
        }

        return storeImagePayloads(payloads, in: noteImagesDirectoryURL, errorContext: "note image")
    }

    func importNoteImages(from images: [NSImage]) -> [String] {
        guard !images.isEmpty else { return [] }

        let payloads = images.compactMap { image -> (data: Data, fileExtension: String)? in
            guard let pngData = pngData(from: image) else {
                return nil
            }
            return (data: pngData, fileExtension: "png")
        }

        return storeImagePayloads(payloads, in: noteImagesDirectoryURL, errorContext: "pasted note image")
    }

    // MARK: - Tasks

    func addTask(title: String) {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        let active = activeTasks()
        let usesManualOrder = active.contains { $0.manualOrder != nil }
        let nextManualOrder = usesManualOrder ? ((active.compactMap(\.manualOrder).max() ?? -1) + 1) : nil
        let now = Date()

        let item = TaskItem(
            title: normalized,
            createdAt: now,
            updatedAt: now,
            completedAt: nil,
            manualOrder: nextManualOrder
        )

        do {
            try database.write { db in
                try item.insert(db)
            }
            reload()
        } catch {
            print("Failed to add task: \(error)")
        }
    }

    func updateTask(taskID: UUID, title: String) {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        let now = Date()

        do {
            try database.write { db in
                try db.execute(
                    sql: """
                    UPDATE taskItem
                    SET title = ?, updatedAt = ?
                    WHERE id = ?
                    """,
                    arguments: [normalized, now, taskID.uuidString]
                )
            }
            reload()
        } catch {
            print("Failed to update task: \(error)")
        }
    }

    func deleteTask(taskID: UUID) {
        do {
            try database.write { db in
                try db.execute(
                    sql: "DELETE FROM taskItem WHERE id = ?",
                    arguments: [taskID.uuidString]
                )
            }
            reload()
        } catch {
            print("Failed to delete task: \(error)")
        }
    }

    func toggleTaskDone(_ task: TaskItem) {
        guard let current = tasks.first(where: { $0.id == task.id }) else { return }
        let now = Date()
        let reopenModeUsesManualOrder = activeTasks(excluding: current.id).contains { $0.manualOrder != nil }
        let reopenManualOrder = reopenModeUsesManualOrder
            ? ((activeTasks(excluding: current.id).compactMap(\.manualOrder).max() ?? -1) + 1)
            : nil

        let nextCompletedAt: Date? = current.isCompleted ? nil : now
        let nextManualOrder: Int? = current.isCompleted ? reopenManualOrder : nil

        do {
            try database.write { db in
                try db.execute(
                    sql: """
                    UPDATE taskItem
                    SET completedAt = ?, manualOrder = ?, updatedAt = ?
                    WHERE id = ?
                    """,
                    arguments: [nextCompletedAt, nextManualOrder, now, current.id.uuidString]
                )
            }
            reload()
        } catch {
            print("Failed to toggle task state: \(error)")
        }
    }

    func reorderActiveTasks(idsInOrder: [UUID]) {
        let active = activeTasks()
        guard !active.isEmpty else { return }

        let normalized = CaptureAlgorithms.normalizeManualOrder(idsInOrder, activeTasks: active)
        let now = Date()

        do {
            try database.write { db in
                for (id, order) in normalized {
                    try db.execute(
                        sql: """
                        UPDATE taskItem
                        SET manualOrder = ?, updatedAt = ?
                        WHERE id = ? AND completedAt IS NULL
                        """,
                        arguments: [order, now, id.uuidString]
                    )
                }
            }
            reload()
        } catch {
            print("Failed to reorder tasks: \(error)")
        }
    }

    func resetTaskOrderToDefault() {
        let now = Date()
        do {
            try database.write { db in
                try db.execute(
                    sql: """
                    UPDATE taskItem
                    SET manualOrder = NULL, updatedAt = ?
                    WHERE completedAt IS NULL
                    """,
                    arguments: [now]
                )
            }
            reload()
        } catch {
            print("Failed to reset task order: \(error)")
        }
    }

    func activeTasks() -> [TaskItem] {
        CaptureAlgorithms.sortedActiveTasks(tasks)
    }

    func completedTasks() -> [TaskItem] {
        CaptureAlgorithms.sortedCompletedTasks(tasks)
    }

    func filteredTasks(_ query: String) -> (active: [TaskItem], completed: [TaskItem]) {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return (activeTasks(), completedTasks())
        }

        let active = activeTasks().filter { $0.title.localizedCaseInsensitiveContains(normalized) }
        let completed = completedTasks().filter { $0.title.localizedCaseInsensitiveContains(normalized) }
        return (active, completed)
    }

    // MARK: - Clips

    func addClip(content: String) {
        guard AppSettings.shared.enableClips, !AppSettings.shared.pauseClips else { return }
        let latest = clips.first(where: { $0.kind == .text })?.content
        guard !CaptureAlgorithms.shouldIgnoreClip(content: content, latestContent: latest) else { return }

        let now = Date()
        let item = ClipItem(
            content: content,
            kind: .text,
            imagePath: nil,
            createdAt: now,
            isPinned: false,
            lastCopiedAt: nil
        )

        do {
            let removedImagePaths = try insertClipAndApplyRetention(item)
            deleteStoredClipImagesIfNeeded(removedImagePaths)
            reload()
        } catch {
            print("Failed to add clip: \(error)")
        }
    }

    func addImageClip(data: Data, preferredExtension: String = "png") {
        guard AppSettings.shared.enableClips, !AppSettings.shared.pauseClips else { return }
        guard !data.isEmpty else { return }

        let ext = sanitizedFileExtension(preferredExtension)
        var createdImagePath: String?

        do {
            let directory = try clipImagesDirectoryURL()
            let destination = directory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            try data.write(to: destination, options: [.atomic])
            createdImagePath = destination.path

            let now = Date()
            let item = ClipItem(
                content: "",
                kind: .image,
                imagePath: destination.path,
                createdAt: now,
                isPinned: false,
                lastCopiedAt: nil
            )
            let removedImagePaths = try insertClipAndApplyRetention(item)
            deleteStoredClipImagesIfNeeded(removedImagePaths)
            reload()
        } catch {
            if let createdImagePath {
                deleteStoredClipImageIfNeeded(createdImagePath)
            }
            print("Failed to add image clip: \(error)")
        }
    }

    func setClipPinned(clipID: UUID, isPinned: Bool) {
        do {
            try database.write { db in
                try db.execute(
                    sql: "UPDATE clipItem SET isPinned = ? WHERE id = ?",
                    arguments: [isPinned, clipID.uuidString]
                )
            }
            reload()
        } catch {
            print("Failed to set clip pin state: \(error)")
        }
    }

    func deleteClip(clipID: UUID) {
        do {
            let removedImagePaths = try database.write { db -> [String] in
                let existing = try ClipItem
                    .filter(ClipItem.Columns.id == clipID.uuidString)
                    .fetchOne(db)
                try db.execute(
                    sql: "DELETE FROM clipItem WHERE id = ?",
                    arguments: [clipID.uuidString]
                )
                return sanitizeImagePaths(existing?.imagePath.map { [$0] } ?? [])
            }
            deleteStoredClipImagesIfNeeded(removedImagePaths)
            reload()
        } catch {
            print("Failed to delete clip: \(error)")
        }
    }

    func clearClips() {
        clearClips(kind: nil)
    }

    func clearTextClips() {
        clearClips(kind: .text)
    }

    func clearImageClips() {
        clearClips(kind: .image)
    }

    private func clearClips(kind: ClipKind?) {
        do {
            let removedImagePaths = try database.write { db -> [String] in
                let existingClips: [ClipItem]
                if let kind {
                    existingClips = try ClipItem
                        .filter(ClipItem.Columns.kind == kind.rawValue)
                        .fetchAll(db)
                    try db.execute(
                        sql: "DELETE FROM clipItem WHERE kind = ?",
                        arguments: [kind.rawValue]
                    )
                } else {
                    existingClips = try ClipItem.fetchAll(db)
                    try db.execute(sql: "DELETE FROM clipItem")
                }
                return sanitizeImagePaths(existingClips.compactMap(\.imagePath))
            }
            deleteStoredClipImagesIfNeeded(removedImagePaths)
            reload()
        } catch {
            let target = kind?.rawValue ?? "all"
            print("Failed to clear \(target) clips: \(error)")
        }
    }

    func recentClips(limit: Int) -> [ClipItem] {
        Array(clips.prefix(limit))
    }

    func imageClips() -> [ClipItem] {
        sortedClipsByNewest(clips.filter(\.isImage))
    }

    func textClips() -> [ClipItem] {
        sortedClipsByNewest(clips.filter { !$0.isImage })
    }

    func searchTextClips(_ query: String) -> [ClipItem] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let textClips = textClips()
        guard !normalized.isEmpty else { return textClips }
        return textClips.filter { $0.content.localizedCaseInsensitiveContains(normalized) }
    }

    func searchClips(_ query: String) -> [ClipItem] {
        searchTextClips(query)
    }

    func copyClipToPasteboard(_ clip: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let didWrite: Bool
        switch clip.kind {
        case .text:
            didWrite = pasteboard.setString(clip.content, forType: .string)
        case .image:
            guard let imagePath = clip.imagePath else {
                return
            }
            didWrite = writeImageToPasteboard(imagePath: imagePath, pasteboard: pasteboard)
        }

        guard didWrite else { return }
        ClipboardMonitor.shared.markInternalCopy(changeCount: pasteboard.changeCount)

        let now = Date()
        do {
            try database.write { db in
                try db.execute(
                    sql: "UPDATE clipItem SET lastCopiedAt = ? WHERE id = ?",
                    arguments: [now, clip.id.uuidString]
                )
            }
            reload()
        } catch {
            print("Failed to mark clip copied: \(error)")
        }
    }

    // MARK: - Helpers

    private func insertClipAndApplyRetention(_ item: ClipItem) throws -> [String] {
        try database.write { db -> [String] in
            try item.insert(db)

            let clipsByOldestFirst = try ClipItem
                .order(ClipItem.Columns.createdAt.asc)
                .fetchAll(db)
            let deleteIDs = CaptureAlgorithms.clipIDsToDeleteForRetention(
                clipsByOldestFirst: clipsByOldestFirst,
                maxCount: maxClipCount
            )
            let deleteSet = Set(deleteIDs)
            let removedImagePaths = clipsByOldestFirst
                .filter { deleteSet.contains($0.id) }
                .compactMap(\.imagePath)

            for clipID in deleteIDs {
                try db.execute(
                    sql: "DELETE FROM clipItem WHERE id = ?",
                    arguments: [clipID.uuidString]
                )
            }

            return sanitizeImagePaths(removedImagePaths)
        }
    }

    private func storeImagePayloads(
        _ payloads: [(data: Data, fileExtension: String)],
        in directoryProvider: () throws -> URL,
        errorContext: String
    ) -> [String] {
        guard !payloads.isEmpty else { return [] }

        do {
            let directory = try directoryProvider()
            var importedPaths: [String] = []

            for payload in payloads where !payload.data.isEmpty {
                let ext = sanitizedFileExtension(payload.fileExtension)
                let destination = directory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(ext)
                do {
                    try payload.data.write(to: destination, options: [.atomic])
                    importedPaths.append(destination.path)
                } catch {
                    print("Failed to store \(errorContext) at \(destination.lastPathComponent): \(error)")
                }
            }

            return sanitizeImagePaths(importedPaths)
        } catch {
            print("Failed to prepare image directory for \(errorContext): \(error)")
            return []
        }
    }

    private func pngData(from image: NSImage) -> Data? {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    private func writeImageToPasteboard(imagePath: String, pasteboard: NSPasteboard) -> Bool {
        let imageURL = URL(fileURLWithPath: imagePath)
        let image = NSImage(contentsOfFile: imagePath)
        let rawData: Data? = {
            let didAccess = imageURL.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    imageURL.stopAccessingSecurityScopedResource()
                }
            }
            return try? Data(contentsOf: imageURL)
        }()

        let item = NSPasteboardItem()

        let ext = imageURL.pathExtension.lowercased()
        if
            let rawData,
            !rawData.isEmpty,
            !ext.isEmpty,
            let type = UTType(filenameExtension: ext),
            type.conforms(to: .image)
        {
            item.setData(rawData, forType: NSPasteboard.PasteboardType(type.identifier))
        }
        item.setString(imageURL.absoluteString, forType: .fileURL)

        if let image, let tiff = image.tiffRepresentation {
            item.setData(tiff, forType: .tiff)
        }

        if let image, let png = pngData(from: image) {
            item.setData(png, forType: NSPasteboard.PasteboardType(UTType.png.identifier))
        }

        if !item.types.isEmpty, pasteboard.writeObjects([item]) {
            return true
        }

        if let image {
            return pasteboard.writeObjects([image])
        }

        if
            let rawData,
            !rawData.isEmpty,
            !ext.isEmpty,
            let type = UTType(filenameExtension: ext),
            type.conforms(to: .image)
        {
            return pasteboard.setData(rawData, forType: NSPasteboard.PasteboardType(type.identifier))
        }

        return false
    }

    private func sanitizedFileExtension(_ raw: String, fallback: String = "png") -> String {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
        guard !normalized.isEmpty else { return fallback }
        let filtered = normalized.filter { $0.isLetter || $0.isNumber }
        return filtered.isEmpty ? fallback : filtered
    }

    private func sortedClipsByNewest(_ clips: [ClipItem]) -> [ClipItem] {
        clips.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.id.uuidString > rhs.id.uuidString
        }
    }

    private func resolvedNoteTitle(_ rawTitle: String?, content: String) -> String {
        let normalizedTitle = (rawTitle ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedTitle.isEmpty {
            return String(normalizedTitle.prefix(60))
        }

        let firstLine = content
            .split(whereSeparator: \.isNewline)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !firstLine.isEmpty {
            return String(firstLine.prefix(60))
        }

        return L10n.string("Untitled Note")
    }

    private func sanitizeImagePaths(_ imagePaths: [String]) -> [String] {
        var seen = Set<String>()
        return imagePaths.compactMap { raw in
            let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else {
                return nil
            }
            return normalized
        }
    }

    private func encodeImagePaths(_ imagePaths: [String]) -> String {
        let normalized = sanitizeImagePaths(imagePaths)
        guard
            let data = try? JSONEncoder().encode(normalized),
            let raw = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return raw
    }

    private func deleteStoredImagesIfNeeded(_ imagePaths: [String]) {
        let safeSet = Set(sanitizeImagePaths(imagePaths))
        guard !safeSet.isEmpty else { return }

        for path in safeSet {
            deleteStoredImageIfNeeded(path)
        }
    }

    private func deleteStoredImageIfNeeded(_ imagePath: String) {
        do {
            let directory = try noteImagesDirectoryURL()
            let targetURL = URL(fileURLWithPath: imagePath)
            guard targetURL.path.hasPrefix(directory.path) else { return }
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
        } catch {
            print("Failed to cleanup note image at \(imagePath): \(error)")
        }
    }

    private func deleteStoredClipImagesIfNeeded(_ imagePaths: [String]) {
        let safeSet = Set(sanitizeImagePaths(imagePaths))
        guard !safeSet.isEmpty else { return }

        for path in safeSet {
            deleteStoredClipImageIfNeeded(path)
        }
    }

    private func deleteStoredClipImageIfNeeded(_ imagePath: String) {
        do {
            let directory = try clipImagesDirectoryURL()
            let targetURL = URL(fileURLWithPath: imagePath)
            guard targetURL.path.hasPrefix(directory.path) else { return }
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
        } catch {
            print("Failed to cleanup clip image at \(imagePath): \(error)")
        }
    }

    private func noteImagesDirectoryURL() throws -> URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport
            .appendingPathComponent("FocusOrb", isDirectory: true)
            .appendingPathComponent("CaptureImages", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func clipImagesDirectoryURL() throws -> URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport
            .appendingPathComponent("FocusOrb", isDirectory: true)
            .appendingPathComponent("ClipImages", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func activeTasks(excluding taskID: UUID) -> [TaskItem] {
        CaptureAlgorithms.sortedActiveTasks(tasks.filter { $0.id != taskID })
    }

    private func refreshDerivedState() {
        topTask = CaptureAlgorithms.topTask(from: tasks)
    }
}
